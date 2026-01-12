#!/bin/bash
set -e

# ========================================
# OpenStack Network Setup
# ========================================
# Creates: Network, Subnet, Router
# No Terraform needed!
# ========================================

echo "=========================================="
echo "🌐 Creating OpenStack Network Infrastructure"
echo "=========================================="

# Load environment variables
if [ -f ~/.openstack-foodhub.env ]; then
    source ~/.openstack-foodhub.env
else
    echo "❌ Error: ~/.openstack-foodhub.env not found"
    echo "Please create it first (see 00-SETUP-GUIDE.md)"
    exit 1
fi

# Configuration
PROJECT_NAME=${PROJECT_NAME:-foodhub}
NETWORK_NAME="${PROJECT_NAME}-network"
SUBNET_NAME="${PROJECT_NAME}-subnet"
ROUTER_NAME="${PROJECT_NAME}-router"
SUBNET_CIDR=${OPENSTACK_SUBNET_CIDR:-10.0.1.0/24}
EXTERNAL_NETWORK=${EXTERNAL_NETWORK:-public}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_green() { echo -e "${GREEN}✅ $1${NC}"; }
print_yellow() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_red() { echo -e "${RED}❌ $1${NC}"; }

# ========================================
# Step 1: Test OpenStack Connection
# ========================================
echo ""
echo "Step 1: Testing OpenStack connection..."

if ! openstack token issue >/dev/null 2>&1; then
    print_red "Cannot connect to OpenStack"
    echo "Check your credentials in ~/.openstack-foodhub.env"
    exit 1
fi

print_green "OpenStack connection successful"

# ========================================
# Step 2: Create Private Network
# ========================================
echo ""
echo "Step 2: Creating private network..."

# Check if network already exists
if openstack network show ${NETWORK_NAME} >/dev/null 2>&1; then
    print_yellow "Network ${NETWORK_NAME} already exists, skipping..."
else
    openstack network create \
        --description "FoodHub private network" \
        ${NETWORK_NAME}

    print_green "Network ${NETWORK_NAME} created"
fi

# Get network ID
NETWORK_ID=$(openstack network show ${NETWORK_NAME} -f value -c id)
echo "Network ID: ${NETWORK_ID}"

# ========================================
# Step 3: Create Subnet
# ========================================
echo ""
echo "Step 3: Creating subnet..."

# Check if subnet already exists
if openstack subnet show ${SUBNET_NAME} >/dev/null 2>&1; then
    print_yellow "Subnet ${SUBNET_NAME} already exists, skipping..."
else
    openstack subnet create \
        --network ${NETWORK_NAME} \
        --subnet-range ${SUBNET_CIDR} \
        --dns-nameserver 8.8.8.8 \
        --dns-nameserver 8.8.4.4 \
        --allocation-pool start=$(echo ${SUBNET_CIDR} | cut -d'/' -f1 | awk -F. '{print $1"."$2"."$3".10"}'),end=$(echo ${SUBNET_CIDR} | cut -d'/' -f1 | awk -F. '{print $1"."$2"."$3".250"}') \
        ${SUBNET_NAME}

    print_green "Subnet ${SUBNET_NAME} created (${SUBNET_CIDR})"
fi

# Get subnet ID
SUBNET_ID=$(openstack subnet show ${SUBNET_NAME} -f value -c id)
echo "Subnet ID: ${SUBNET_ID}"

# ========================================
# Step 4: Create Router
# ========================================
echo ""
echo "Step 4: Creating router..."

# Check if router already exists
if openstack router show ${ROUTER_NAME} >/dev/null 2>&1; then
    print_yellow "Router ${ROUTER_NAME} already exists, skipping..."
else
    # Get external network ID
    EXTERNAL_NETWORK_ID=$(openstack network show ${EXTERNAL_NETWORK} -f value -c id 2>/dev/null || echo "")

    if [ -z "${EXTERNAL_NETWORK_ID}" ]; then
        print_red "External network '${EXTERNAL_NETWORK}' not found"
        echo "Available networks:"
        openstack network list
        echo ""
        echo "Please set EXTERNAL_NETWORK in ~/.openstack-foodhub.env"
        exit 1
    fi

    # Create router
    openstack router create \
        --description "FoodHub router with external connectivity" \
        ${ROUTER_NAME}

    # Set external gateway
    openstack router set \
        --external-gateway ${EXTERNAL_NETWORK_ID} \
        ${ROUTER_NAME}

    print_green "Router ${ROUTER_NAME} created with external gateway"
fi

# Get router ID
ROUTER_ID=$(openstack router show ${ROUTER_NAME} -f value -c id)
echo "Router ID: ${ROUTER_ID}"

# ========================================
# Step 5: Connect Router to Subnet
# ========================================
echo ""
echo "Step 5: Connecting router to subnet..."

# Check if already connected
ROUTER_PORTS=$(openstack port list --router ${ROUTER_NAME} -f value -c id)
SUBNET_CONNECTED=false

for PORT_ID in ${ROUTER_PORTS}; do
    PORT_SUBNET=$(openstack port show ${PORT_ID} -f json | jq -r '.fixed_ips[0].subnet_id')
    if [ "${PORT_SUBNET}" == "${SUBNET_ID}" ]; then
        SUBNET_CONNECTED=true
        break
    fi
done

if [ "${SUBNET_CONNECTED}" == "true" ]; then
    print_yellow "Router already connected to subnet, skipping..."
else
    openstack router add subnet ${ROUTER_NAME} ${SUBNET_NAME}
    print_green "Router connected to subnet"
fi

# ========================================
# Summary
# ========================================
echo ""
echo "=========================================="
echo "🎉 Network Infrastructure Created!"
echo "=========================================="
echo ""
echo "📋 Resources:"
echo "  Network:  ${NETWORK_NAME} (${NETWORK_ID})"
echo "  Subnet:   ${SUBNET_NAME} (${SUBNET_ID})"
echo "            CIDR: ${SUBNET_CIDR}"
echo "  Router:   ${ROUTER_NAME} (${ROUTER_ID})"
echo "            External Gateway: ${EXTERNAL_NETWORK}"
echo ""
echo "🔍 Verify with:"
echo "  openstack network list"
echo "  openstack subnet list"
echo "  openstack router list"
echo ""
echo "✅ Ready for VM creation!"
echo "=========================================="

# Save configuration for next scripts
cat > /tmp/foodhub-network-config.sh <<EOF
# Auto-generated by 01-create-network.sh
export NETWORK_NAME="${NETWORK_NAME}"
export NETWORK_ID="${NETWORK_ID}"
export SUBNET_NAME="${SUBNET_NAME}"
export SUBNET_ID="${SUBNET_ID}"
export ROUTER_NAME="${ROUTER_NAME}"
export ROUTER_ID="${ROUTER_ID}"
export SUBNET_CIDR="${SUBNET_CIDR}"
EOF

print_green "Network configuration saved to /tmp/foodhub-network-config.sh"
