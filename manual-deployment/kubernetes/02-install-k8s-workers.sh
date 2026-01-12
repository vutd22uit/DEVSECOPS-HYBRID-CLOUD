#!/bin/bash
set -e

# ========================================
# Kubernetes Worker Nodes Installation
# ========================================

echo "=========================================="
echo "☸️  Installing Kubernetes Worker Nodes"
echo "=========================================="

# Load IPs
source /tmp/foodhub-ips.sh

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_green() { echo -e "${GREEN}✅ $1${NC}"; }
print_blue() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Check join command exists
if [ ! -f /tmp/kubeadm-join-command.sh ]; then
    echo "❌ Join command not found!"
    echo "Please run ./kubernetes/01-install-k8s-master.sh first"
    exit 1
fi

JOIN_COMMAND=$(cat /tmp/kubeadm-join-command.sh)

# ========================================
# Install on each worker
# ========================================

for WORKER_NUM in 1 2 3; do
    WORKER_VAR="WORKER${WORKER_NUM}_IP"
    WORKER_IP=${!WORKER_VAR}

    echo ""
    echo "=========================================="
    echo "Installing Worker ${WORKER_NUM}: ${WORKER_IP}"
    echo "=========================================="

    # Create installation script (same as master, without init)
    cat > /tmp/install-k8s-worker-${WORKER_NUM}.sh <<'WORKER_SCRIPT'
#!/bin/bash
set -e

echo "Installing Kubernetes worker components..."

# Update system
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install prerequisites
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Install containerd
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Add Kubernetes repository
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Get private IP and configure kubelet
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "KUBELET_EXTRA_ARGS=--node-ip=$PRIVATE_IP" | sudo tee /etc/default/kubelet

# Enable kubelet
sudo systemctl enable kubelet

echo "✅ Kubernetes worker components installed"

WORKER_SCRIPT

    # Copy and execute
    print_blue "Installing Kubernetes on worker ${WORKER_NUM}..."
    scp -o StrictHostKeyChecking=no -i ${SSH_KEY} /tmp/install-k8s-worker-${WORKER_NUM}.sh ubuntu@${WORKER_IP}:/tmp/
    ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${WORKER_IP} "bash /tmp/install-k8s-worker-${WORKER_NUM}.sh"

    # Join cluster
    print_blue "Joining worker ${WORKER_NUM} to cluster..."
    ssh -i ${SSH_KEY} ubuntu@${WORKER_IP} "sudo ${JOIN_COMMAND}"

    print_green "Worker ${WORKER_NUM} joined cluster"
    sleep 5
done

# ========================================
# Verify cluster
# ========================================

echo ""
echo "=========================================="
echo "Verifying cluster..."
echo "=========================================="

export KUBECONFIG=~/.kube/config-foodhub-openstack

echo "Waiting for all nodes to be Ready..."
sleep 30

kubectl get nodes

echo ""
echo "=========================================="
echo "🎉 Kubernetes Cluster Setup Complete!"
echo "=========================================="
echo ""
echo "📋 Cluster Status:"
kubectl get nodes -o wide
echo ""
echo "🔍 Pods:"
kubectl get pods -A
echo ""
echo "✅ Cluster ready for deployments!"
echo "=========================================="
