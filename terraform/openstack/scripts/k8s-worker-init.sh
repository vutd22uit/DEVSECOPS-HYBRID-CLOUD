#!/bin/bash
set -e

# Kubernetes Worker Node Initialization Script
# This script will be run via cloud-init on worker nodes

echo "=========================================="
echo "Kubernetes Worker Node Initialization"
echo "=========================================="

# Variables (will be templated by Terraform)
MASTER_IP="${master_ip}"

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

# Configure kubelet with node IP
INTERNAL_IP=$(hostname -I | awk '{print $1}')
echo "KUBELET_EXTRA_ARGS=--node-ip=$INTERNAL_IP" > /etc/default/kubelet

# Enable kubelet service
systemctl enable kubelet

echo "=========================================="
echo "Kubernetes Worker Node Initialization Complete!"
echo "=========================================="
echo "Node is ready to join the cluster."
echo ""
echo "To join this node to the cluster, run on master:"
echo "  cat /root/kubeadm-join-command.sh"
echo ""
echo "Then execute the join command on this worker node."
echo "=========================================="
