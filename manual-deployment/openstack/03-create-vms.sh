#!/bin/bash
set -e

# ========================================
# OpenStack VMs Creation
# ========================================
# Creates:
# - 1 Kubernetes Master
# - 3 Kubernetes Workers
# - 1 PostgreSQL Database
# - 1 Harbor Registry
# - 1 VPN Gateway
# ========================================

echo "=========================================="
echo "🖥️  Creating OpenStack Virtual Machines"
echo "=========================================="

# Load environment
source ~/.openstack-foodhub.env
source /tmp/foodhub-network-config.sh 2>/dev/null || true
source /tmp/foodhub-security-groups.sh 2>/dev/null || true

# Configuration
PROJECT_NAME=${PROJECT_NAME:-foodhub}
IMAGE_NAME=${IMAGE_NAME:-"ubuntu-22.04"}  # Change to your image name
KEYPAIR_NAME=${KEYPAIR_NAME:-"${PROJECT_NAME}-key"}

# Flavors (adjust based on your OpenStack)
MASTER_FLAVOR=${MASTER_FLAVOR:-"m1.medium"}    # 2 vCPU, 4GB RAM
WORKER_FLAVOR=${WORKER_FLAVOR:-"m1.large"}     # 4 vCPU, 8GB RAM
DB_FLAVOR=${DB_FLAVOR:-"m1.medium"}            # 2 vCPU, 4GB RAM
HARBOR_FLAVOR=${HARBOR_FLAVOR:-"m1.large"}     # 4 vCPU, 8GB RAM
VPN_FLAVOR=${VPN_FLAVOR:-"m1.small"}           # 1 vCPU, 2GB RAM

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_green() { echo -e "${GREEN}✅ $1${NC}"; }
print_yellow() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_blue() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# ========================================
# Prerequisite: SSH Key
# ========================================
echo ""
echo "Step 1: Checking SSH keypair..."

if ! openstack keypair show ${KEYPAIR_NAME} >/dev/null 2>&1; then
    echo "Creating SSH keypair..."

    # Generate local key if not exists
    if [ ! -f ~/.ssh/${KEYPAIR_NAME} ]; then
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/${KEYPAIR_NAME} -N "" -C "foodhub-openstack-key"
    fi

    # Upload to OpenStack
    openstack keypair create \
        --public-key ~/.ssh/${KEYPAIR_NAME}.pub \
        ${KEYPAIR_NAME}

    print_green "SSH keypair created: ${KEYPAIR_NAME}"
else
    print_yellow "SSH keypair ${KEYPAIR_NAME} already exists"
fi

# ========================================
# Prerequisite: Check Image
# ========================================
echo ""
echo "Step 2: Checking OS image..."

if ! openstack image show ${IMAGE_NAME} >/dev/null 2>&1; then
    echo "❌ Image ${IMAGE_NAME} not found!"
    echo "Available images:"
    openstack image list
    echo ""
    echo "Please set IMAGE_NAME in ~/.openstack-foodhub.env"
    exit 1
fi

IMAGE_ID=$(openstack image show ${IMAGE_NAME} -f value -c id)
print_green "Using image: ${IMAGE_NAME} (${IMAGE_ID})"

# ========================================
# Function: Create VM
# ========================================
create_vm() {
    local VM_NAME=$1
    local FLAVOR=$2
    local SECURITY_GROUP=$3
    local USER_DATA=$4

    echo ""
    echo "Creating VM: ${VM_NAME}..."

    # Check if VM exists
    if openstack server show ${VM_NAME} >/dev/null 2>&1; then
        print_yellow "VM ${VM_NAME} already exists, skipping..."
        return 0
    fi

    # Create VM
    local CMD="openstack server create \
        --flavor ${FLAVOR} \
        --image ${IMAGE_NAME} \
        --key-name ${KEYPAIR_NAME} \
        --network ${NETWORK_NAME} \
        --security-group ${SECURITY_GROUP}"

    if [ ! -z "${USER_DATA}" ]; then
        CMD="${CMD} --user-data ${USER_DATA}"
    fi

    CMD="${CMD} ${VM_NAME}"

    eval ${CMD} >/dev/null

    print_green "VM ${VM_NAME} created"

    # Wait for VM to be active
    echo "  Waiting for VM to be ACTIVE..."
    local count=0
    while [ $count -lt 60 ]; do
        local status=$(openstack server show ${VM_NAME} -f value -c status)
        if [ "${status}" == "ACTIVE" ]; then
            print_green "VM ${VM_NAME} is ACTIVE"
            break
        fi
        sleep 5
        count=$((count + 1))
        echo -n "."
    done
    echo ""
}

# ========================================
# Function: Allocate and Assign Floating IP
# ========================================
assign_floating_ip() {
    local VM_NAME=$1

    # Check if already has floating IP
    local EXISTING_FIP=$(openstack server show ${VM_NAME} -f json | jq -r '.addresses' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -1)

    # Create floating IP
    print_blue "Allocating floating IP for ${VM_NAME}..."
    local FIP=$(openstack floating ip create ${EXTERNAL_NETWORK} -f value -c floating_ip_address)

    # Assign to VM
    openstack server add floating ip ${VM_NAME} ${FIP}

    print_green "Floating IP ${FIP} assigned to ${VM_NAME}"
    echo "${FIP}" > /tmp/${VM_NAME}-ip.txt
}

# ========================================
# 3. Create Kubernetes Master
# ========================================
echo ""
echo "=========================================="
echo "3️⃣  Creating Kubernetes Master Node"
echo "=========================================="

create_vm "${PROJECT_NAME}-k8s-master" \
          "${MASTER_FLAVOR}" \
          "${SG_K8S_MASTER}"

assign_floating_ip "${PROJECT_NAME}-k8s-master"

# ========================================
# 4. Create Kubernetes Workers
# ========================================
echo ""
echo "=========================================="
echo "4️⃣  Creating Kubernetes Worker Nodes"
echo "=========================================="

for i in 1 2 3; do
    create_vm "${PROJECT_NAME}-k8s-worker-${i}" \
              "${WORKER_FLAVOR}" \
              "${SG_K8S_WORKER}"

    assign_floating_ip "${PROJECT_NAME}-k8s-worker-${i}"
done

# ========================================
# 5. Create PostgreSQL Server
# ========================================
echo ""
echo "=========================================="
echo "5️⃣  Creating PostgreSQL Database Server"
echo "=========================================="

create_vm "${PROJECT_NAME}-postgresql" \
          "${DB_FLAVOR}" \
          "${SG_POSTGRESQL}"

assign_floating_ip "${PROJECT_NAME}-postgresql"

# ========================================
# 6. Create Harbor Registry
# ========================================
echo ""
echo "=========================================="
echo "6️⃣  Creating Harbor Registry Server"
echo "=========================================="

create_vm "${PROJECT_NAME}-harbor" \
          "${HARBOR_FLAVOR}" \
          "${SG_HARBOR}"

assign_floating_ip "${PROJECT_NAME}-harbor"

# ========================================
# 7. Create VPN Gateway
# ========================================
echo ""
echo "=========================================="
echo "7️⃣  Creating VPN Gateway"
echo "=========================================="

create_vm "${PROJECT_NAME}-vpn-gateway" \
          "${VPN_FLAVOR}" \
          "${SG_VPN}"

assign_floating_ip "${PROJECT_NAME}-vpn-gateway"

# ========================================
# Summary
# ========================================
echo ""
echo "=========================================="
echo "🎉 All VMs Created Successfully!"
echo "=========================================="
echo ""
echo "📋 VM Summary:"
openstack server list --name ${PROJECT_NAME} -c Name -c Status -c Networks

echo ""
echo "🌐 Floating IPs:"
echo ""

MASTER_IP=$(cat /tmp/${PROJECT_NAME}-k8s-master-ip.txt)
echo "  K8s Master:    ${MASTER_IP}"

for i in 1 2 3; do
    WORKER_IP=$(cat /tmp/${PROJECT_NAME}-k8s-worker-${i}-ip.txt)
    echo "  K8s Worker ${i}:  ${WORKER_IP}"
done

PG_IP=$(cat /tmp/${PROJECT_NAME}-postgresql-ip.txt)
echo "  PostgreSQL:    ${PG_IP}"

HARBOR_IP=$(cat /tmp/${PROJECT_NAME}-harbor-ip.txt)
echo "  Harbor:        ${HARBOR_IP}"

VPN_IP=$(cat /tmp/${PROJECT_NAME}-vpn-gateway-ip.txt)
echo "  VPN Gateway:   ${VPN_IP}"

echo ""
echo "🔑 SSH Access:"
echo "  ssh -i ~/.ssh/${KEYPAIR_NAME} ubuntu@${MASTER_IP}"
echo ""
echo "📝 IP addresses saved to /tmp/${PROJECT_NAME}-*-ip.txt"
echo ""

# Save all IPs
cat > /tmp/foodhub-ips.sh <<EOF
# Auto-generated by 03-create-vms.sh
export MASTER_IP="${MASTER_IP}"
export WORKER1_IP="$(cat /tmp/${PROJECT_NAME}-k8s-worker-1-ip.txt)"
export WORKER2_IP="$(cat /tmp/${PROJECT_NAME}-k8s-worker-2-ip.txt)"
export WORKER3_IP="$(cat /tmp/${PROJECT_NAME}-k8s-worker-3-ip.txt)"
export PG_IP="${PG_IP}"
export HARBOR_IP="${HARBOR_IP}"
export VPN_IP="${VPN_IP}"
export SSH_KEY="~/.ssh/${KEYPAIR_NAME}"
EOF

print_green "All IPs saved to /tmp/foodhub-ips.sh"

echo ""
echo "⏱️  VMs are now initializing..."
echo "    Wait ~5 minutes for cloud-init to complete"
echo ""
echo "✅ Next step: Install Kubernetes"
echo "    ./kubernetes/01-install-k8s-master.sh"
echo "=========================================="
