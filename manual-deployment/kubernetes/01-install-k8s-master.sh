#!/bin/bash
set -e

# ========================================
# Kubernetes Master Node Installation
# ========================================
# Installs and configures Kubernetes master
# No Terraform needed!
# ========================================

echo "=========================================="
echo "☸️  Installing Kubernetes Master Node"
echo "=========================================="

# Load IPs
source /tmp/foodhub-ips.sh

# Configuration
K8S_VERSION="1.28"
POD_CIDR="192.168.0.0/16"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_green() { echo -e "${GREEN}✅ $1${NC}"; }
print_blue() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# ========================================
# Install Kubernetes on Master
# ========================================

echo ""
print_blue "Connecting to master node: ${MASTER_IP}"

# Create installation script
cat > /tmp/install-k8s-master-remote.sh <<'MASTER_SCRIPT'
#!/bin/bash
set -e

echo "=========================================="
echo "Installing Kubernetes Master Components"
echo "=========================================="

# Update system
echo "1. Updating system..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install required packages
echo "2. Installing prerequisites..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Disable swap
echo "3. Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules
echo "4. Loading kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl
echo "5. Configuring sysctl..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Install containerd
echo "6. Installing containerd..."
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Add Kubernetes repository
echo "7. Adding Kubernetes repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes components
echo "8. Installing kubelet, kubeadm, kubectl..."
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
sudo systemctl enable kubelet

echo "✅ Kubernetes components installed"
echo "Ready for cluster initialization..."

MASTER_SCRIPT

# Copy and execute on master
echo ""
echo "Copying installation script to master..."
scp -o StrictHostKeyChecking=no -i ${SSH_KEY} /tmp/install-k8s-master-remote.sh ubuntu@${MASTER_IP}:/tmp/

echo "Executing installation on master (this will take ~10 minutes)..."
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ubuntu@${MASTER_IP} "bash /tmp/install-k8s-master-remote.sh"

print_green "Kubernetes components installed on master"

# ========================================
# Initialize Kubernetes Cluster
# ========================================

echo ""
echo "=========================================="
echo "Initializing Kubernetes Cluster"
echo "=========================================="

# Get master's private IP
MASTER_PRIVATE_IP=$(ssh -i ${SSH_KEY} ubuntu@${MASTER_IP} "hostname -I | awk '{print \$1}'")

echo "Master Private IP: ${MASTER_PRIVATE_IP}"

# Create kubeadm config
cat > /tmp/kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${MASTER_PRIVATE_IP}
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  kubeletExtraArgs:
    node-ip: ${MASTER_PRIVATE_IP}
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
controlPlaneEndpoint: "${MASTER_PRIVATE_IP}:6443"
networking:
  podSubnet: ${POD_CIDR}
  serviceSubnet: 10.96.0.0/12
apiServer:
  certSANs:
  - ${MASTER_PRIVATE_IP}
  - ${MASTER_IP}
  - localhost
  - 127.0.0.1
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF

echo "Copying kubeadm config to master..."
scp -i ${SSH_KEY} /tmp/kubeadm-config.yaml ubuntu@${MASTER_IP}:/tmp/

echo "Initializing cluster (this may take 5-10 minutes)..."
ssh -i ${SSH_KEY} ubuntu@${MASTER_IP} "sudo kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs"

print_green "Kubernetes cluster initialized"

# ========================================
# Configure kubectl
# ========================================

echo ""
echo "Configuring kubectl..."

ssh -i ${SSH_KEY} ubuntu@${MASTER_IP} <<'EOF'
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
EOF

print_green "kubectl configured for ubuntu user"

# ========================================
# Install CNI (Calico)
# ========================================

echo ""
echo "Installing Calico CNI..."

ssh -i ${SSH_KEY} ubuntu@${MASTER_IP} "kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml"

print_green "Calico CNI installed"

# ========================================
# Generate join command
# ========================================

echo ""
echo "Generating worker join command..."

ssh -i ${SSH_KEY} ubuntu@${MASTER_IP} "kubeadm token create --print-join-command" > /tmp/kubeadm-join-command.sh
chmod +x /tmp/kubeadm-join-command.sh

print_green "Join command saved to /tmp/kubeadm-join-command.sh"

# ========================================
# Install Helm
# ========================================

echo ""
echo "Installing Helm..."

ssh -i ${SSH_KEY} ubuntu@${MASTER_IP} "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"

print_green "Helm installed"

# ========================================
# Download kubeconfig
# ========================================

echo ""
echo "Downloading kubeconfig to local machine..."

mkdir -p ~/.kube
scp -i ${SSH_KEY} ubuntu@${MASTER_IP}:.kube/config ~/.kube/config-foodhub-openstack

# Update server address to use floating IP
sed -i "s|https://.*:6443|https://${MASTER_IP}:6443|" ~/.kube/config-foodhub-openstack

print_green "kubeconfig downloaded to ~/.kube/config-foodhub-openstack"

# ========================================
# Wait for cluster to be ready
# ========================================

echo ""
echo "Waiting for cluster to be ready..."

export KUBECONFIG=~/.kube/config-foodhub-openstack

count=0
while [ $count -lt 30 ]; do
    if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
        print_green "Cluster is ready!"
        break
    fi
    sleep 10
    count=$((count + 1))
    echo -n "."
done
echo ""

# ========================================
# Summary
# ========================================

echo ""
echo "=========================================="
echo "🎉 Kubernetes Master Installation Complete!"
echo "=========================================="
echo ""
echo "📋 Cluster Info:"
kubectl --kubeconfig=~/.kube/config-foodhub-openstack cluster-info
echo ""
echo "🖥️  Nodes:"
kubectl --kubeconfig=~/.kube/config-foodhub-openstack get nodes
echo ""
echo "🔑 Access cluster:"
echo "  export KUBECONFIG=~/.kube/config-foodhub-openstack"
echo "  kubectl get nodes"
echo ""
echo "🔗 API Server:"
echo "  https://${MASTER_IP}:6443"
echo ""
echo "✅ Next step: Install worker nodes"
echo "    ./kubernetes/02-install-k8s-workers.sh"
echo "=========================================="
