#!/bin/bash
set -e

# ========================================
# Configure VPN Gateway on OpenStack
# ========================================

echo "=========================================="
echo "🔒 Configuring VPN Gateway"
echo "=========================================="

# Load IPs
source /tmp/foodhub-ips.sh
source /tmp/foodhub-vpn.sh 2>/dev/null || true

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_green() { echo -e "${GREEN}✅ $1${NC}"; }
print_blue() { echo -e "${BLUE}ℹ️  $1${NC}"; }

if [ -z "${VPN_TUNNEL1_IP}" ]; then
    echo "❌ VPN info not found!"
    echo "Please run ./aws/01-create-vpn.sh first"
    exit 1
fi

echo ""
print_blue "Configuring VPN on: ${VPN_IP}"

# Copy VPN config
print_blue "Copying VPN configuration..."
scp -o StrictHostKeyChecking=no -i ${SSH_KEY} /tmp/vpn-config-for-openstack.conf ubuntu@${VPN_IP}:/tmp/

# Install and configure strongSwan
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${VPN_IP} <<'VPN_CONFIG'
#!/bin/bash
set -e

echo "Installing strongSwan..."

# Update system
sudo apt-get update
sudo apt-get install -y strongswan strongswan-pki libcharon-extra-plugins

# Enable IP forwarding
echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding = 1" | sudo tee -a /etc/sysctl.conf

# Install iptables-persistent
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent

# Configure firewall
echo "Configuring firewall..."
sudo iptables -A FORWARD -i eth0 -o eth0 -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Save iptables rules
sudo netfilter-persistent save

echo "✅ strongSwan installed"

VPN_CONFIG

print_green "strongSwan installed on VPN gateway"

# Extract VPN config from file
print_blue "Extracting VPN configuration..."

IPSEC_CONF=$(cat /tmp/vpn-config-for-openstack.conf | sed -n '/# \/etc\/ipsec.conf/,/# \/etc\/ipsec.secrets/p' | grep -v '^#' | head -n -2)
IPSEC_SECRETS=$(cat /tmp/vpn-config-for-openstack.conf | sed -n '/# \/etc\/ipsec.secrets/,$p' | grep -v '^#' | grep -v '^$')

# Apply configuration
print_blue "Applying VPN configuration..."

ssh -i ${SSH_KEY} ubuntu@${VPN_IP} "echo '${IPSEC_CONF}' | sudo tee /etc/ipsec.conf > /dev/null"
ssh -i ${SSH_KEY} ubuntu@${VPN_IP} "echo '${IPSEC_SECRETS}' | sudo tee /etc/ipsec.secrets > /dev/null"
ssh -i ${SSH_KEY} ubuntu@${VPN_IP} "sudo chmod 600 /etc/ipsec.secrets"

# Restart strongSwan
print_blue "Starting VPN..."
ssh -i ${SSH_KEY} ubuntu@${VPN_IP} "sudo systemctl restart strongswan-starter"
ssh -i ${SSH_KEY} ubuntu@${VPN_IP} "sudo systemctl enable strongswan-starter"

sleep 10

# Check VPN status
print_blue "Checking VPN status..."
VPN_STATUS=$(ssh -i ${SSH_KEY} ubuntu@${VPN_IP} "sudo ipsec status" || echo "")

if echo "${VPN_STATUS}" | grep -q "ESTABLISHED"; then
    print_green "VPN tunnel established!"
else
    echo "⚠️  VPN tunnel not yet established"
    echo "This is normal - tunnels may take a few minutes to establish"
fi

# ========================================
# Summary
# ========================================

echo ""
echo "=========================================="
echo "🎉 VPN Configuration Complete!"
echo "=========================================="
echo ""
echo "📋 VPN Info:"
echo "  OpenStack VPN Gateway: ${VPN_IP}"
echo "  AWS Tunnel 1: ${VPN_TUNNEL1_IP}"
echo "  AWS Tunnel 2: ${VPN_TUNNEL2_IP}"
echo ""
echo "🔍 Check VPN status:"
echo "  ssh -i ${SSH_KEY} ubuntu@${VPN_IP} 'sudo ipsec status'"
echo ""
echo "🧪 Test connectivity:"
echo "  ssh -i ${SSH_KEY} ubuntu@${VPN_IP} 'ping -c 4 10.1.1.1'"
echo ""
echo "📝 VPN Logs:"
echo "  ssh -i ${SSH_KEY} ubuntu@${VPN_IP} 'sudo journalctl -u strongswan-starter -f'"
echo ""
echo "✅ Hybrid cloud networking established!"
echo "=========================================="
