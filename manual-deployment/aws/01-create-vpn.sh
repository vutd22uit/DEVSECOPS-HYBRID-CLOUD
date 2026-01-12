#!/bin/bash
set -e

# ========================================
# AWS VPN Setup (Manual - AWS CLI)
# ========================================

echo "=========================================="
echo "🔒 Creating AWS VPN Connection"
echo "=========================================="

# Load environment
source ~/.openstack-foodhub.env
source /tmp/foodhub-ips.sh

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_green() { echo -e "${GREEN}✅ $1${NC}"; }
print_yellow() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_blue() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Configuration
AWS_REGION=${AWS_REGION:-ap-southeast-1}
VPC_ID=${VPC_ID:-""}  # Will auto-detect
OPENSTACK_VPN_IP=${VPN_IP}
PRE_SHARED_KEY=${PRE_SHARED_KEY:-"FoodHub-VPN-PSK-Change-Me-2025"}

# ========================================
# Get VPC ID
# ========================================

echo ""
print_blue "Finding VPC..."

if [ -z "${VPC_ID}" ]; then
    VPC_ID=$(aws ec2 describe-vpcs \
        --region ${AWS_REGION} \
        --filters "Name=tag:Name,Values=foodhub-vpc" \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null || echo "")

    if [ -z "${VPC_ID}" ] || [ "${VPC_ID}" == "None" ]; then
        echo "No VPC found with tag Name=foodhub-vpc"
        echo "Available VPCs:"
        aws ec2 describe-vpcs --region ${AWS_REGION} --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table
        echo ""
        read -p "Enter VPC ID: " VPC_ID
    fi
fi

print_green "Using VPC: ${VPC_ID}"

VPC_CIDR=$(aws ec2 describe-vpcs --region ${AWS_REGION} --vpc-ids ${VPC_ID} --query 'Vpcs[0].CidrBlock' --output text)
echo "VPC CIDR: ${VPC_CIDR}"

# ========================================
# Create Customer Gateway
# ========================================

echo ""
print_blue "Creating Customer Gateway for OpenStack VPN..."

CGW_ID=$(aws ec2 describe-customer-gateways \
    --region ${AWS_REGION} \
    --filters "Name=ip-address,Values=${OPENSTACK_VPN_IP}" \
    --query 'CustomerGateways[0].CustomerGatewayId' \
    --output text 2>/dev/null || echo "None")

if [ "${CGW_ID}" == "None" ]; then
    CGW_ID=$(aws ec2 create-customer-gateway \
        --region ${AWS_REGION} \
        --type ipsec.1 \
        --public-ip ${OPENSTACK_VPN_IP} \
        --bgp-asn 65000 \
        --tag-specifications "ResourceType=customer-gateway,Tags=[{Key=Name,Value=foodhub-openstack-cgw}]" \
        --query 'CustomerGateway.CustomerGatewayId' \
        --output text)

    print_green "Customer Gateway created: ${CGW_ID}"
else
    print_yellow "Customer Gateway already exists: ${CGW_ID}"
fi

# ========================================
# Create Virtual Private Gateway
# ========================================

echo ""
print_blue "Creating Virtual Private Gateway..."

VGW_ID=$(aws ec2 describe-vpn-gateways \
    --region ${AWS_REGION} \
    --filters "Name=tag:Name,Values=foodhub-vpn-gateway" "Name=state,Values=available" \
    --query 'VpnGateways[0].VpnGatewayId' \
    --output text 2>/dev/null || echo "None")

if [ "${VGW_ID}" == "None" ]; then
    VGW_ID=$(aws ec2 create-vpn-gateway \
        --region ${AWS_REGION} \
        --type ipsec.1 \
        --amazon-side-asn 64512 \
        --tag-specifications "ResourceType=vpn-gateway,Tags=[{Key=Name,Value=foodhub-vpn-gateway}]" \
        --query 'VpnGateway.VpnGatewayId' \
        --output text)

    print_green "VPN Gateway created: ${VGW_ID}"

    # Attach to VPC
    print_blue "Attaching VPN Gateway to VPC..."
    aws ec2 attach-vpn-gateway \
        --region ${AWS_REGION} \
        --vpn-gateway-id ${VGW_ID} \
        --vpc-id ${VPC_ID}

    # Wait for attachment
    sleep 10
else
    print_yellow "VPN Gateway already exists: ${VGW_ID}"
fi

# ========================================
# Create VPN Connection
# ========================================

echo ""
print_blue "Creating VPN Connection..."

VPN_ID=$(aws ec2 describe-vpn-connections \
    --region ${AWS_REGION} \
    --filters "Name=tag:Name,Values=foodhub-openstack-vpn" "Name=state,Values=available" \
    --query 'VpnConnections[0].VpnConnectionId' \
    --output text 2>/dev/null || echo "None")

if [ "${VPN_ID}" == "None" ]; then
    VPN_ID=$(aws ec2 create-vpn-connection \
        --region ${AWS_REGION} \
        --type ipsec.1 \
        --customer-gateway-id ${CGW_ID} \
        --vpn-gateway-id ${VGW_ID} \
        --options "StaticRoutesOnly=true,TunnelOptions=[{PreSharedKey=${PRE_SHARED_KEY}},{PreSharedKey=${PRE_SHARED_KEY}}]" \
        --tag-specifications "ResourceType=vpn-connection,Tags=[{Key=Name,Value=foodhub-openstack-vpn}]" \
        --query 'VpnConnection.VpnConnectionId' \
        --output text)

    print_green "VPN Connection created: ${VPN_ID}"

    # Wait for VPN to be available
    print_blue "Waiting for VPN connection to be available..."
    aws ec2 wait vpn-connection-available --region ${AWS_REGION} --vpn-connection-ids ${VPN_ID}
else
    print_yellow "VPN Connection already exists: ${VPN_ID}"
fi

# ========================================
# Add static route for OpenStack network
# ========================================

echo ""
print_blue "Adding static route for OpenStack network..."

aws ec2 create-vpn-connection-route \
    --region ${AWS_REGION} \
    --vpn-connection-id ${VPN_ID} \
    --destination-cidr-block ${OPENSTACK_NETWORK_CIDR} 2>/dev/null || print_yellow "Route may already exist"

# ========================================
# Enable route propagation
# ========================================

echo ""
print_blue "Enabling route propagation..."

# Get route table IDs
ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables \
    --region ${AWS_REGION} \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
    --query 'RouteTables[*].RouteTableId' \
    --output text)

for RTB_ID in ${ROUTE_TABLE_IDS}; do
    aws ec2 enable-vgw-route-propagation \
        --region ${AWS_REGION} \
        --route-table-id ${RTB_ID} \
        --gateway-id ${VGW_ID} 2>/dev/null || print_yellow "Route propagation may already be enabled for ${RTB_ID}"
done

# ========================================
# Get VPN configuration
# ========================================

echo ""
print_blue "Getting VPN configuration..."

VPN_CONFIG=$(aws ec2 describe-vpn-connections \
    --region ${AWS_REGION} \
    --vpn-connection-ids ${VPN_ID} \
    --output json)

TUNNEL1_IP=$(echo ${VPN_CONFIG} | jq -r '.VpnConnections[0].VgwTelemetry[0].OutsideIpAddress')
TUNNEL2_IP=$(echo ${VPN_CONFIG} | jq -r '.VpnConnections[0].VgwTelemetry[1].OutsideIpAddress')
TUNNEL1_CIDR=$(echo ${VPN_CONFIG} | jq -r '.VpnConnections[0].Options.TunnelOptions[0].TunnelInsideCidr')
TUNNEL2_CIDR=$(echo ${VPN_CONFIG} | jq -r '.VpnConnections[0].Options.TunnelOptions[1].TunnelInsideCidr')

# ========================================
# Create VPN config file for OpenStack
# ========================================

cat > /tmp/vpn-config-for-openstack.conf <<EOF
# ========================================
# AWS VPN Configuration for OpenStack strongSwan
# ========================================

VPN Connection ID: ${VPN_ID}
Customer Gateway: ${CGW_ID} (${OPENSTACK_VPN_IP})
Virtual Private Gateway: ${VGW_ID}

Tunnel 1:
  AWS Endpoint: ${TUNNEL1_IP}
  Inside CIDR: ${TUNNEL1_CIDR}
  Pre-shared Key: ${PRE_SHARED_KEY}

Tunnel 2:
  AWS Endpoint: ${TUNNEL2_IP}
  Inside CIDR: ${TUNNEL2_CIDR}
  Pre-shared Key: ${PRE_SHARED_KEY}

Local Network: ${OPENSTACK_NETWORK_CIDR}
Remote Network: ${VPC_CIDR}

# ========================================
# /etc/ipsec.conf
# ========================================

config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2, mgr 2"
    uniqueids=never

conn aws-tunnel1
    type=tunnel
    authby=secret
    left=%defaultroute
    leftsubnet=${OPENSTACK_NETWORK_CIDR}
    right=${TUNNEL1_IP}
    rightsubnet=${VPC_CIDR}
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256-modp2048!
    keyingtries=%forever
    ikelifetime=8h
    lifetime=1h
    dpddelay=10s
    dpdtimeout=30s
    dpdaction=restart
    auto=start

conn aws-tunnel2
    type=tunnel
    authby=secret
    left=%defaultroute
    leftsubnet=${OPENSTACK_NETWORK_CIDR}
    right=${TUNNEL2_IP}
    rightsubnet=${VPC_CIDR}
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256-modp2048!
    keyingtries=%forever
    ikelifetime=8h
    lifetime=1h
    dpddelay=10s
    dpdtimeout=30s
    dpdaction=restart
    auto=start

# ========================================
# /etc/ipsec.secrets
# ========================================

: PSK "${PRE_SHARED_KEY}"

EOF

# ========================================
# Summary
# ========================================

echo ""
echo "=========================================="
echo "🎉 AWS VPN Connection Created!"
echo "=========================================="
echo ""
echo "📋 Resources:"
echo "  Customer Gateway:  ${CGW_ID}"
echo "  VPN Gateway:       ${VGW_ID}"
echo "  VPN Connection:    ${VPN_ID}"
echo ""
echo "🌐 Tunnels:"
echo "  Tunnel 1: ${TUNNEL1_IP} (${TUNNEL1_CIDR})"
echo "  Tunnel 2: ${TUNNEL2_IP} (${TUNNEL2_CIDR})"
echo ""
echo "🔑 Pre-shared Key: ${PRE_SHARED_KEY}"
echo ""
echo "📄 VPN configuration saved to:"
echo "  /tmp/vpn-config-for-openstack.conf"
echo ""
echo "✅ Next step: Configure OpenStack VPN Gateway"
echo "    ./openstack/06-configure-vpn.sh"
echo "=========================================="

# Save VPN info
cat > /tmp/foodhub-vpn.sh <<EOF
export VPN_CONNECTION_ID="${VPN_ID}"
export VPN_TUNNEL1_IP="${TUNNEL1_IP}"
export VPN_TUNNEL2_IP="${TUNNEL2_IP}"
export VPN_PRE_SHARED_KEY="${PRE_SHARED_KEY}"
EOF

print_green "VPN info saved to /tmp/foodhub-vpn.sh"
