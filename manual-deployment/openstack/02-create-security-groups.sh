#!/bin/bash
set -e

# ========================================
# OpenStack Security Groups Setup
# ========================================
# Creates security groups for:
# - Kubernetes Master
# - Kubernetes Workers
# - PostgreSQL Database
# - Harbor Registry
# - VPN Gateway
# ========================================

echo "=========================================="
echo "🔒 Creating OpenStack Security Groups"
echo "=========================================="

# Load environment
source ~/.openstack-foodhub.env

# Configuration
PROJECT_NAME=${PROJECT_NAME:-foodhub}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_green() { echo -e "${GREEN}✅ $1${NC}"; }
print_yellow() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# ========================================
# Function: Create Security Group
# ========================================
create_sg() {
    local SG_NAME=$1
    local SG_DESC=$2

    if openstack security group show ${SG_NAME} >/dev/null 2>&1; then
        print_yellow "Security group ${SG_NAME} already exists"
        return 0
    fi

    openstack security group create \
        --description "${SG_DESC}" \
        ${SG_NAME}

    print_green "Security group ${SG_NAME} created"
}

# ========================================
# Function: Add Security Group Rule
# ========================================
add_rule() {
    local SG_NAME=$1
    local PROTOCOL=$2
    local PORT_MIN=$3
    local PORT_MAX=$4
    local CIDR=$5
    local DESC=$6

    # Check if rule exists (simplified check)
    local EXISTING=$(openstack security group rule list ${SG_NAME} \
        --protocol ${PROTOCOL} \
        --ingress \
        -f value -c "Port Range" 2>/dev/null | grep "${PORT_MIN}:${PORT_MAX}" || echo "")

    if [ ! -z "${EXISTING}" ]; then
        print_yellow "Rule already exists: ${PROTOCOL} ${PORT_MIN}:${PORT_MAX}"
        return 0
    fi

    openstack security group rule create \
        --protocol ${PROTOCOL} \
        --dst-port ${PORT_MIN}:${PORT_MAX} \
        --remote-ip ${CIDR} \
        --description "${DESC}" \
        ${SG_NAME} >/dev/null

    echo "  + ${DESC}"
}

# ========================================
# 1. Kubernetes Master Security Group
# ========================================
echo ""
echo "1️⃣  Creating Kubernetes Master security group..."

SG_K8S_MASTER="${PROJECT_NAME}-k8s-master-sg"
create_sg ${SG_K8S_MASTER} "Security group for Kubernetes master nodes"

echo "Adding rules for ${SG_K8S_MASTER}..."
add_rule ${SG_K8S_MASTER} tcp 22 22 "0.0.0.0/0" "SSH"
add_rule ${SG_K8S_MASTER} tcp 6443 6443 "0.0.0.0/0" "Kubernetes API Server"
add_rule ${SG_K8S_MASTER} tcp 2379 2380 "10.0.0.0/16" "etcd"
add_rule ${SG_K8S_MASTER} tcp 10250 10250 "10.0.0.0/16" "Kubelet API"
add_rule ${SG_K8S_MASTER} tcp 10259 10259 "10.0.0.0/16" "kube-scheduler"
add_rule ${SG_K8S_MASTER} tcp 10257 10257 "10.0.0.0/16" "kube-controller-manager"
add_rule ${SG_K8S_MASTER} tcp 1 65535 "10.0.0.0/16" "All internal traffic"

# Allow all egress
openstack security group rule create \
    --protocol any \
    --egress \
    ${SG_K8S_MASTER} >/dev/null 2>&1 || true

print_green "Kubernetes Master SG configured"

# ========================================
# 2. Kubernetes Worker Security Group
# ========================================
echo ""
echo "2️⃣  Creating Kubernetes Worker security group..."

SG_K8S_WORKER="${PROJECT_NAME}-k8s-worker-sg"
create_sg ${SG_K8S_WORKER} "Security group for Kubernetes worker nodes"

echo "Adding rules for ${SG_K8S_WORKER}..."
add_rule ${SG_K8S_WORKER} tcp 22 22 "0.0.0.0/0" "SSH"
add_rule ${SG_K8S_WORKER} tcp 80 80 "0.0.0.0/0" "HTTP"
add_rule ${SG_K8S_WORKER} tcp 443 443 "0.0.0.0/0" "HTTPS"
add_rule ${SG_K8S_WORKER} tcp 30000 32767 "0.0.0.0/0" "NodePort Services"
add_rule ${SG_K8S_WORKER} tcp 10250 10250 "10.0.0.0/16" "Kubelet API"
add_rule ${SG_K8S_WORKER} tcp 1 65535 "10.0.0.0/16" "All internal traffic"

# Allow all egress
openstack security group rule create \
    --protocol any \
    --egress \
    ${SG_K8S_WORKER} >/dev/null 2>&1 || true

print_green "Kubernetes Worker SG configured"

# ========================================
# 3. PostgreSQL Security Group
# ========================================
echo ""
echo "3️⃣  Creating PostgreSQL security group..."

SG_POSTGRESQL="${PROJECT_NAME}-postgresql-sg"
create_sg ${SG_POSTGRESQL} "Security group for PostgreSQL database"

echo "Adding rules for ${SG_POSTGRESQL}..."
add_rule ${SG_POSTGRESQL} tcp 22 22 "0.0.0.0/0" "SSH"
add_rule ${SG_POSTGRESQL} tcp 5432 5432 "10.0.0.0/16" "PostgreSQL from OpenStack"
add_rule ${SG_POSTGRESQL} tcp 5432 5432 "10.1.0.0/16" "PostgreSQL from AWS"

# Allow all egress
openstack security group rule create \
    --protocol any \
    --egress \
    ${SG_POSTGRESQL} >/dev/null 2>&1 || true

print_green "PostgreSQL SG configured"

# ========================================
# 4. Harbor Registry Security Group
# ========================================
echo ""
echo "4️⃣  Creating Harbor security group..."

SG_HARBOR="${PROJECT_NAME}-harbor-sg"
create_sg ${SG_HARBOR} "Security group for Harbor container registry"

echo "Adding rules for ${SG_HARBOR}..."
add_rule ${SG_HARBOR} tcp 22 22 "0.0.0.0/0" "SSH"
add_rule ${SG_HARBOR} tcp 80 80 "0.0.0.0/0" "HTTP"
add_rule ${SG_HARBOR} tcp 443 443 "0.0.0.0/0" "HTTPS"

# Allow all egress
openstack security group rule create \
    --protocol any \
    --egress \
    ${SG_HARBOR} >/dev/null 2>&1 || true

print_green "Harbor SG configured"

# ========================================
# 5. VPN Gateway Security Group
# ========================================
echo ""
echo "5️⃣  Creating VPN Gateway security group..."

SG_VPN="${PROJECT_NAME}-vpn-sg"
create_sg ${SG_VPN} "Security group for VPN Gateway to AWS"

echo "Adding rules for ${SG_VPN}..."
add_rule ${SG_VPN} tcp 22 22 "0.0.0.0/0" "SSH"

# IPSec rules
openstack security group rule create \
    --protocol udp \
    --dst-port 500:500 \
    --remote-ip "0.0.0.0/0" \
    --description "IPSec IKE" \
    ${SG_VPN} >/dev/null 2>&1 || true
echo "  + IPSec IKE (UDP 500)"

openstack security group rule create \
    --protocol udp \
    --dst-port 4500:4500 \
    --remote-ip "0.0.0.0/0" \
    --description "IPSec NAT-T" \
    ${SG_VPN} >/dev/null 2>&1 || true
echo "  + IPSec NAT-T (UDP 4500)"

openstack security group rule create \
    --protocol 50 \
    --remote-ip "0.0.0.0/0" \
    --description "ESP protocol" \
    ${SG_VPN} >/dev/null 2>&1 || true
echo "  + ESP protocol"

# Allow all egress
openstack security group rule create \
    --protocol any \
    --egress \
    ${SG_VPN} >/dev/null 2>&1 || true

print_green "VPN Gateway SG configured"

# ========================================
# Summary
# ========================================
echo ""
echo "=========================================="
echo "🎉 Security Groups Created!"
echo "=========================================="
echo ""
echo "📋 Security Groups:"
echo "  1. ${SG_K8S_MASTER}"
echo "  2. ${SG_K8S_WORKER}"
echo "  3. ${SG_POSTGRESQL}"
echo "  4. ${SG_HARBOR}"
echo "  5. ${SG_VPN}"
echo ""
echo "🔍 Verify with:"
echo "  openstack security group list"
echo "  openstack security group rule list <sg-name>"
echo ""
echo "✅ Ready for VM creation!"
echo "=========================================="

# Save SG names for next scripts
cat > /tmp/foodhub-security-groups.sh <<EOF
# Auto-generated by 02-create-security-groups.sh
export SG_K8S_MASTER="${SG_K8S_MASTER}"
export SG_K8S_WORKER="${SG_K8S_WORKER}"
export SG_POSTGRESQL="${SG_POSTGRESQL}"
export SG_HARBOR="${SG_HARBOR}"
export SG_VPN="${SG_VPN}"
EOF

print_green "Security group config saved to /tmp/foodhub-security-groups.sh"
