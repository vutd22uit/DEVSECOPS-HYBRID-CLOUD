# 🛠️ Manual Deployment Guide - Hybrid Cloud (OpenStack + AWS)

> **No Terraform Required!** Tất cả cấu hình bằng tay với OpenStack CLI và AWS CLI

## 📋 Tổng Quan

Hướng dẫn này sẽ giúp bạn setup Hybrid Cloud **hoàn toàn manual** với:
- ✅ OpenStack CLI commands
- ✅ AWS CLI commands
- ✅ Shell scripts tự động hóa
- ✅ Không cần Terraform

---

## 🔧 Cài Đặt Tools

### 1. OpenStack CLI

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y python3-pip python3-openstackclient

# Hoặc via pip
pip3 install python-openstackclient python-neutronclient python-novaclient

# Verify
openstack --version
```

### 2. AWS CLI

```bash
# Ubuntu/Debian
sudo apt-get install -y awscli

# Hoặc via pip
pip3 install awscli

# Configure
aws configure
# Nhập: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, region=ap-southeast-1

# Verify
aws --version
```

### 3. Other Tools

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# jq (JSON parser)
sudo apt-get install -y jq

# PostgreSQL client
sudo apt-get install -y postgresql-client
```

---

## 🌐 Setup Environment

Tạo file `.env`:

```bash
cat > ~/.openstack-foodhub.env <<'EOF'
# OpenStack Credentials
export OS_AUTH_URL="http://your-openstack-controller:5000/v3"
export OS_USERNAME="admin"
export OS_PASSWORD="your-openstack-password"
export OS_PROJECT_NAME="foodhub"
export OS_USER_DOMAIN_NAME="Default"
export OS_PROJECT_DOMAIN_NAME="Default"
export OS_REGION_NAME="RegionOne"

# AWS Credentials
export AWS_REGION="ap-southeast-1"
export AWS_ACCOUNT_ID="257394468168"

# Network Configuration
export OPENSTACK_NETWORK_CIDR="10.0.0.0/16"
export OPENSTACK_SUBNET_CIDR="10.0.1.0/24"
export AWS_VPC_CIDR="10.1.0.0/16"

# Project Configuration
export PROJECT_NAME="foodhub"
export EXTERNAL_NETWORK="public"  # Tên external network của OpenStack
EOF

# Load environment
source ~/.openstack-foodhub.env
```

---

## 📂 Deployment Steps

### Phase 1: OpenStack Infrastructure
1. **Network Setup** (10 phút)
   ```bash
   ./manual-deployment/openstack/01-create-network.sh
   ```

2. **Security Groups** (5 phút)
   ```bash
   ./manual-deployment/openstack/02-create-security-groups.sh
   ```

3. **Create VMs** (30 phút)
   ```bash
   ./manual-deployment/openstack/03-create-vms.sh
   ```

### Phase 2: Kubernetes Cluster
4. **Install Kubernetes** (30 phút)
   ```bash
   ./manual-deployment/kubernetes/01-install-k8s-master.sh
   ./manual-deployment/kubernetes/02-install-k8s-workers.sh
   ```

### Phase 3: Services
5. **Harbor Registry** (15 phút)
   ```bash
   ./manual-deployment/openstack/04-install-harbor.sh
   ```

6. **PostgreSQL** (10 phút)
   ```bash
   ./manual-deployment/openstack/05-install-postgresql.sh
   ```

### Phase 4: AWS Integration
7. **AWS VPN Setup** (20 phút)
   ```bash
   ./manual-deployment/aws/01-create-vpn.sh
   ```

8. **VPN Configuration** (15 phút)
   ```bash
   ./manual-deployment/openstack/06-configure-vpn.sh
   ```

### Phase 5: GitOps & Monitoring
9. **ArgoCD** (10 phút)
   ```bash
   ./manual-deployment/kubernetes/03-install-argocd.sh
   ```

10. **Monitoring** (10 phút)
    ```bash
    ./manual-deployment/monitoring/01-install-prometheus.sh
    ```

---

## ⏱️ Timeline

| Phase | Time | Description |
|-------|------|-------------|
| Phase 1 | 45 min | OpenStack infrastructure |
| Phase 2 | 30 min | Kubernetes cluster |
| Phase 3 | 25 min | Harbor + PostgreSQL |
| Phase 4 | 35 min | AWS VPN integration |
| Phase 5 | 20 min | ArgoCD + Monitoring |
| **Total** | **~2.5 hours** | Complete deployment |

---

## 🚀 Quick Start

```bash
# 1. Load environment
source ~/.openstack-foodhub.env

# 2. Verify OpenStack connection
openstack server list

# 3. Verify AWS connection
aws ec2 describe-vpcs

# 4. Run all scripts in order
cd manual-deployment

# OpenStack
./openstack/01-create-network.sh
./openstack/02-create-security-groups.sh
./openstack/03-create-vms.sh

# Wait for VMs to be ready (check with: openstack server list)

# Kubernetes
./kubernetes/01-install-k8s-master.sh
./kubernetes/02-install-k8s-workers.sh

# Services
./openstack/04-install-harbor.sh
./openstack/05-install-postgresql.sh

# AWS VPN
./aws/01-create-vpn.sh
./openstack/06-configure-vpn.sh

# GitOps
./kubernetes/03-install-argocd.sh

# Monitoring
./monitoring/01-install-prometheus.sh
```

---

## 📝 Manual Commands Reference

### OpenStack Common Commands

```bash
# List all servers
openstack server list

# Show server details
openstack server show <server-name>

# Get floating IP
openstack floating ip list

# SSH to VM
ssh ubuntu@<floating-ip>

# Create volume
openstack volume create --size 50 <volume-name>

# Attach volume
openstack server add volume <server> <volume>

# Network list
openstack network list

# Security group list
openstack security group list
```

### AWS Common Commands

```bash
# List VPCs
aws ec2 describe-vpcs

# List VPN connections
aws ec2 describe-vpn-connections

# Get VPN configuration
aws ec2 describe-vpn-connections --vpn-connection-ids <vpn-id>

# List customer gateways
aws ec2 describe-customer-gateways

# List VPN gateways
aws ec2 describe-vpn-gateways
```

---

## ✅ Verification Checklist

```bash
# OpenStack
□ Network created: openstack network show foodhub-network
□ VMs running: openstack server list
□ Floating IPs assigned: openstack floating ip list
□ Security groups configured: openstack security group list

# Kubernetes
□ Master ready: ssh ubuntu@<master-ip> "kubectl get nodes"
□ Workers joined: kubectl get nodes
□ Pods running: kubectl get pods -A

# Services
□ Harbor accessible: curl http://<harbor-ip>
□ PostgreSQL running: psql -h <pg-ip> -U postgres -c "SELECT 1"

# VPN
□ VPN created on AWS: aws ec2 describe-vpn-connections
□ VPN configured on OpenStack: ssh ubuntu@<vpn-ip> "sudo ipsec status"
□ Connectivity test: ping 10.1.1.1 (from OpenStack)

# GitOps
□ ArgoCD running: kubectl get pods -n argocd
□ Clusters registered: argocd cluster list
```

---

## 🔧 Troubleshooting

### OpenStack Issues

**Problem: Cannot connect to OpenStack**
```bash
# Check credentials
openstack token issue

# If fails, verify env vars
env | grep OS_

# Test with simple command
openstack server list
```

**Problem: No floating IPs available**
```bash
# Check floating IP pool
openstack floating ip list

# Create more if needed
openstack floating ip create <external-network>
```

### AWS Issues

**Problem: AWS CLI not configured**
```bash
# Reconfigure
aws configure

# Or set env vars
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="ap-southeast-1"
```

### SSH Issues

**Problem: Cannot SSH to VMs**
```bash
# Check security group allows SSH
openstack security group rule list <security-group>

# Check SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/foodhub-key
openstack keypair create --public-key ~/.ssh/foodhub-key.pub foodhub-key

# SSH with key
ssh -i ~/.ssh/foodhub-key ubuntu@<floating-ip>
```

---

## 📚 Next Steps

Sau khi setup xong environment:

1. **Review Scripts**: Đọc qua các scripts trong `manual-deployment/`
2. **Customize**: Chỉnh sửa variables nếu cần
3. **Deploy**: Chạy scripts theo thứ tự
4. **Verify**: Check từng bước với verification commands
5. **Test**: Deploy sample application

---

## 🆘 Support

- 📖 **Documentation**: Xem README trong từng folder
- 🐛 **Issues**: Nếu lỗi, check logs trong `/var/log/`
- 💡 **Tips**: Mỗi script có comments chi tiết

---

**Prepared by**: DevOps Team
**Last Updated**: 2025-01-12
**Version**: 1.0.0 (Manual Deployment)
