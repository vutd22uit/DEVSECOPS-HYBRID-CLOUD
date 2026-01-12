#!/bin/bash
set -e

# Kubernetes Master Node Initialization Script
# This script will be run via cloud-init on master nodes

echo "=========================================="
echo "Kubernetes Master Node Initialization"
echo "=========================================="

# Variables (will be templated by Terraform)
K8S_VERSION="${k8s_version}"
POD_CIDR="${pod_cidr}"

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Disable swap (required for Kubernetes)
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configure sysctl
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install containerd
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Add Kubernetes repository
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes components
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Enable kubelet service
systemctl enable kubelet

# Initialize Kubernetes cluster
HOSTNAME=$(hostname -f)
INTERNAL_IP=$(hostname -I | awk '{print $1}')

# Create kubeadm config
cat <<KUBEADM_EOF > /root/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $INTERNAL_IP
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  kubeletExtraArgs:
    node-ip: $INTERNAL_IP
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v$K8S_VERSION
controlPlaneEndpoint: "$INTERNAL_IP:6443"
networking:
  podSubnet: $POD_CIDR
  serviceSubnet: 10.96.0.0/12
apiServer:
  certSANs:
  - $INTERNAL_IP
  - $HOSTNAME
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
KUBEADM_EOF

# Initialize cluster
kubeadm init --config=/root/kubeadm-config.yaml --upload-certs

# Setup kubeconfig for root user
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config

# Setup kubeconfig for ubuntu user
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Install Calico CNI
kubectl --kubeconfig=/root/.kube/config apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# Generate join command for worker nodes
kubeadm token create --print-join-command > /root/kubeadm-join-command.sh
chmod +x /root/kubeadm-join-command.sh

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
kubectl --kubeconfig=/root/.kube/config wait --for=condition=Ready nodes --all --timeout=300s

echo "=========================================="
echo "Kubernetes Master Node Initialization Complete!"
echo "=========================================="
echo "Kubernetes API: https://$INTERNAL_IP:6443"
echo "Join command saved to: /root/kubeadm-join-command.sh"
echo ""
echo "To access the cluster from remote:"
echo "1. Copy /root/.kube/config to your local machine"
echo "2. Update server address to use floating IP"
echo "=========================================="
