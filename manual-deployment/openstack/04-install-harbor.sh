#!/bin/bash
set -e

# ========================================
# Harbor Container Registry Installation
# ========================================

echo "=========================================="
echo "🐳 Installing Harbor Container Registry"
echo "=========================================="

# Load IPs
source /tmp/foodhub-ips.sh

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_green() { echo -e "${GREEN}✅ $1${NC}"; }
print_blue() { echo -e "${BLUE}ℹ️  $1${NC}"; }

HARBOR_VERSION="v2.10.0"
HARBOR_PASSWORD="FoodHub@2025"

echo ""
print_blue "Installing Harbor on: ${HARBOR_IP}"

# Create installation script
cat > /tmp/install-harbor.sh <<'HARBOR_SCRIPT'
#!/bin/bash
set -e

echo "Installing Harbor Registry..."

# Update system
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Install Docker
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Download Harbor
echo "Downloading Harbor..."
cd /opt
sudo wget https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-offline-installer-v2.10.0.tgz
sudo tar xzvf harbor-offline-installer-v2.10.0.tgz
cd harbor

# Configure Harbor
echo "Configuring Harbor..."
sudo cp harbor.yml.tmpl harbor.yml

# Get hostname
HOSTNAME=$(hostname -I | awk '{print $1}')

# Update configuration
sudo sed -i "s/hostname: reg.mydomain.com/hostname: $HOSTNAME/" harbor.yml
sudo sed -i "s/harbor_admin_password: Harbor12345/harbor_admin_password: HARBOR_PASSWORD_PLACEHOLDER/" harbor.yml

# Disable HTTPS for now (can be enabled later)
sudo sed -i 's/^https:/#https:/' harbor.yml
sudo sed -i 's/^  port: 443/#  port: 443/' harbor.yml
sudo sed -i 's/^  certificate:/#  certificate:/' harbor.yml
sudo sed -i 's/^  private_key:/#  private_key:/' harbor.yml

# Install Harbor
echo "Installing Harbor..."
sudo ./install.sh --with-trivy --with-chartmuseum

echo "✅ Harbor installed successfully!"

HARBOR_SCRIPT

# Replace password placeholder
sed -i "s/HARBOR_PASSWORD_PLACEHOLDER/${HARBOR_PASSWORD}/" /tmp/install-harbor.sh

# Copy and execute
print_blue "Copying installation script..."
scp -o StrictHostKeyChecking=no -i ${SSH_KEY} /tmp/install-harbor.sh ubuntu@${HARBOR_IP}:/tmp/

print_blue "Installing Harbor (this may take 10-15 minutes)..."
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${HARBOR_IP} "bash /tmp/install-harbor.sh"

print_green "Harbor installation complete"

# ========================================
# Summary
# ========================================

echo ""
echo "=========================================="
echo "🎉 Harbor Installation Complete!"
echo "=========================================="
echo ""
echo "🌐 Harbor URL: http://${HARBOR_IP}"
echo "👤 Username:   admin"
echo "🔑 Password:   ${HARBOR_PASSWORD}"
echo ""
echo "🔗 Docker login:"
echo "  docker login ${HARBOR_IP}"
echo ""
echo "📦 Create project 'foodhub' in Harbor UI"
echo "=========================================="

# Save Harbor info
cat > /tmp/foodhub-harbor.sh <<EOF
export HARBOR_URL="http://${HARBOR_IP}"
export HARBOR_USER="admin"
export HARBOR_PASSWORD="${HARBOR_PASSWORD}"
EOF

print_green "Harbor info saved to /tmp/foodhub-harbor.sh"
