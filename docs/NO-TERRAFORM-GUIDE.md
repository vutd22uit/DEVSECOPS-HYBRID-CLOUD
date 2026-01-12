# 🚀 Triển Khai DevSecOps Hybrid Cloud (Không Dùng Terraform)

> **100% Manual Deployment** với Shell Scripts, AWS CLI, OpenStack CLI

---

## 📋 Tổng Quan

Hướng dẫn này mô tả cách triển khai **đầy đủ** hệ thống DevSecOps Hybrid Cloud **KHÔNG sử dụng Terraform**, thay vào đó sử dụng:

| Tool | Mục Đích |
|------|----------|
| **OpenStack CLI** | Quản lý private cloud |
| **AWS CLI + eksctl** | Quản lý public cloud |
| **kubectl** | Quản lý Kubernetes |
| **Shell Scripts** | Tự động hóa các bước |

---

## 🏗️ Kiến Trúc

```
┌─────────────────────────────┐    VPN    ┌─────────────────────────────┐
│   OPENSTACK (Private)       │◄─────────►│   AWS (Public)              │
│                             │           │                             │
│  ┌─────────────────────┐    │           │  ┌─────────────────────┐    │
│  │ Kubernetes Cluster  │    │           │  │ EKS Cluster         │    │
│  │  • Master Node      │    │           │  │  • Managed Nodes    │    │
│  │  • 2 Worker Nodes   │    │           │  │  • ALB Controller   │    │
│  └─────────────────────┘    │           │  └─────────────────────┘    │
│                             │           │                             │
│  ┌─────────────────────┐    │           │  ┌─────────────────────┐    │
│  │ Harbor Registry     │◄───┼───────────┼──│ ECR Registry        │    │
│  └─────────────────────┘    │  Sync     │  └─────────────────────┘    │
│                             │           │                             │
│  ┌─────────────────────┐    │           │  ┌─────────────────────┐    │
│  │ PostgreSQL          │    │           │  │ RDS PostgreSQL      │    │
│  │ (Primary)           │────┼───────────┼──│ (Replica)           │    │
│  └─────────────────────┘    │  Replicate│  └─────────────────────┘    │
│                             │           │                             │
│  ┌─────────────────────┐    │           │                             │
│  │ VPN Gateway         │◄───┼───────────┼──►AWS VPN Gateway           │
│  │ (strongSwan)        │    │           │                             │
│  └─────────────────────┘    │           │                             │
└─────────────────────────────┘           └─────────────────────────────┘
           │                                           │
           └───────────────┬───────────────────────────┘
                           │
                    ┌──────┴──────┐
                    │   Jenkins   │
                    │   ArgoCD    │
                    │   Grafana   │
                    └─────────────┘
```

---

## ⏱️ Timeline Tổng Thể

| Phase | Thời Gian | Mô Tả |
|-------|-----------|-------|
| 1. Prerequisites | 15 min | Cài đặt tools |
| 2. OpenStack Setup | 60 min | Network, VMs, Services |
| 3. Kubernetes Setup | 30 min | Master + Workers |
| 4. AWS Setup (Optional) | 30 min | EKS, ECR, RDS |
| 5. VPN Setup | 15 min | Site-to-Site VPN |
| 6. CI/CD Setup | 30 min | Jenkins, ArgoCD |
| 7. Observability | 15 min | Prometheus, Grafana |
| **TOTAL** | **~3 hours** | Full Hybrid Deployment |

---

## 📦 Prerequisites

### 1. Cài Đặt Tools

```bash
# OpenStack CLI
pip3 install python-openstackclient

# AWS CLI
pip3 install awscli
aws configure

# eksctl (để tạo EKS cluster)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# kubectl
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# jq
sudo apt-get install -y jq
```

### 2. Tạo File Environment

```bash
cat > ~/.openstack-foodhub.env << 'EOF'
# OpenStack credentials
export OS_AUTH_URL="http://your-openstack:5000/v3"
export OS_USERNAME="admin"
export OS_PASSWORD="your-password"
export OS_PROJECT_NAME="foodhub"
export OS_USER_DOMAIN_NAME="Default"
export OS_PROJECT_DOMAIN_NAME="Default"
export OS_REGION_NAME="RegionOne"

# AWS settings
export AWS_REGION="ap-southeast-1"
export AWS_ACCOUNT_ID="your-account-id"

# Project settings
export PROJECT_NAME="foodhub"
export OPENSTACK_SUBNET_CIDR="10.0.1.0/24"
export AWS_VPC_CIDR="10.1.0.0/16"
export EXTERNAL_NETWORK="public"
EOF

source ~/.openstack-foodhub.env
```

---

## 🚀 Deployment Guide

### Phase 1: OpenStack Infrastructure

```bash
cd manual-deployment

# 1. Tạo Network infrastructure
./openstack/01-create-network.sh

# 2. Tạo Security Groups
./openstack/02-create-security-groups.sh

# 3. Tạo VMs (30-40 phút)
./openstack/03-create-vms.sh
```

> ⏱️ **Đợi 5 phút** cho VMs khởi động hoàn tất

### Phase 2: Kubernetes Cluster

```bash
# 4. Cài đặt Kubernetes Master (15 phút)
./kubernetes/01-install-k8s-master.sh

# 5. Cài đặt Workers và join cluster (15 phút)
./kubernetes/02-install-k8s-workers.sh

# Verify
export KUBECONFIG=~/.kube/config-foodhub-openstack
kubectl get nodes
# Mong đợi: 3 nodes Ready
```

### Phase 3: Infrastructure Services

```bash
# 6. Cài đặt Harbor Registry (15 phút)
./openstack/04-install-harbor.sh

# 7. Cài đặt PostgreSQL
./openstack/05-install-postgresql.sh

# 8. Cài đặt ArgoCD
./openstack/07-install-argocd.sh

# 9. Cài đặt Prometheus + Grafana
./openstack/08-install-prometheus-grafana.sh
```

### Phase 4: AWS Setup (Optional - Hybrid Mode)

```bash
cd manual-deployment/aws

# 1. Tạo EKS Cluster (15-20 phút)
./01-create-eks-cluster.sh

# 2. Tạo ECR Repositories
./02-create-ecr-repos.sh

# 3. Tạo RDS PostgreSQL (10 phút)
./03-create-rds-postgresql.sh

# 4. Setup VPN Connection
./01-create-vpn.sh

# Back to OpenStack to configure VPN
cd ../openstack
./06-configure-vpn.sh
```

### Phase 5: CI/CD Setup

```bash
# Ở thư mục gốc dự án
cd /path/to/DEVSECOPS-HYBRID-CLOUD

# Start Jenkins + SonarQube locally
./quick-start.sh

# Hoặc dùng docker-compose
docker-compose up -d
```

**Sau khi Jenkins chạy:**

1. Truy cập `http://localhost:8080`
2. Đăng nhập: `admin` / `admin123`
3. Cấu hình credentials:
   - `github-pat`: GitHub Personal Access Token
   - `sonar-token`: SonarQube Token
   - `harbor-credentials`: Harbor username/password (nếu dùng)

4. Tạo Pipeline mới:
   - Pipeline script from SCM
   - Git URL: Your repo
   - Script Path: `CICD/Jenkinsfile.no-terraform`

### Phase 6: Deploy Applications

```bash
# Option 1: Manual deploy với Kustomize
kubectl apply -k k8s/deployments/overlays/openstack/

# Option 2: ArgoCD GitOps
kubectl apply -f k8s/argocd/multi-cluster/applicationset-hybrid.yaml

# Verify deployments
kubectl get pods -n foodhub
kubectl get svc -n foodhub
kubectl get ingress -n foodhub
```

---

## 🔍 Verification Checklist

### OpenStack Verification

```bash
source ~/.openstack-foodhub.env

# ✅ Token hoạt động
openstack token issue

# ✅ VMs running
openstack server list
# Mong đợi: k8s-master, k8s-worker-1, k8s-worker-2, harbor, postgres, vpn

# ✅ Network ready
openstack network list
openstack router list
openstack floating ip list
```

### Kubernetes Verification

```bash
export KUBECONFIG=~/.kube/config-foodhub-openstack

# ✅ Nodes ready
kubectl get nodes -o wide
# Mong đợi: 3 nodes, status Ready

# ✅ Core pods running
kubectl get pods -A
# Mong đợi: kube-system pods running

# ✅ Application pods
kubectl get pods -n foodhub
# Mong đợi: foodhub-users, products, orders, frontend pods running

# ✅ Services
kubectl get svc -n foodhub
```

### Harbor Verification

```bash
source /tmp/foodhub-harbor.sh

# ✅ Harbor accessible
curl -k https://${HARBOR_IP}

# ✅ Login works
docker login ${HARBOR_IP} -u admin -p ${HARBOR_PASSWORD}
```

### VPN Verification (Hybrid Mode)

```bash
source /tmp/foodhub-vpn.sh

# ✅ VPN tunnel established
ssh -i ~/.ssh/foodhub-key ubuntu@${VPN_IP} "sudo ipsec status"
# Mong đợi: ESTABLISHED

# ✅ Cross-cloud ping
ssh -i ~/.ssh/foodhub-key ubuntu@${VPN_IP} "ping -c 4 10.1.1.1"
# Mong đợi: Ping successful
```

### AWS Verification (Hybrid Mode)

```bash
# ✅ EKS cluster
aws eks describe-cluster --name foodhub-eks --region ap-southeast-1

# ✅ ECR repos
aws ecr describe-repositories --region ap-southeast-1

# ✅ RDS instance
aws rds describe-db-instances --region ap-southeast-1

# ✅ VPN connection
aws ec2 describe-vpn-connections --region ap-southeast-1
```

---

## 📊 Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| **Jenkins** | http://localhost:8080 | admin / admin123 |
| **SonarQube** | http://localhost:9000 | admin / admin |
| **ArgoCD** | Run: `kubectl port-forward svc/argocd-server -n argocd 8443:443` | admin / (from secret) |
| **Grafana** | Run: `kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80` | admin / admin123 |
| **Prometheus** | Run: `kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090` | - |
| **Harbor** | https://HARBOR_IP | admin / Harbor12345 |
| **Frontend** | http://foodhub.local OR via Ingress | - |

---

## 🔧 Troubleshooting

### OpenStack Issues

**Problem: "Cannot connect to OpenStack"**
```bash
# Check credentials
env | grep OS_
openstack token issue

# Re-source environment
source ~/.openstack-foodhub.env
```

**Problem: "VM creation failed"**
```bash
# Check quota
openstack quota show

# Check flavors
openstack flavor list

# Check images
openstack image list
```

### Kubernetes Issues

**Problem: "Nodes NotReady"**
```bash
# Check kubelet
ssh -i ~/.ssh/foodhub-key ubuntu@MASTER_IP "sudo systemctl status kubelet"

# Check logs
ssh -i ~/.ssh/foodhub-key ubuntu@MASTER_IP "sudo journalctl -u kubelet -f"
```

**Problem: "Pods CrashLoopBackOff"**
```bash
kubectl describe pod POD_NAME -n foodhub
kubectl logs POD_NAME -n foodhub --previous
```

### VPN Issues

**Problem: "Tunnel not established"**
```bash
# Check strongSwan
ssh -i ~/.ssh/foodhub-key ubuntu@VPN_IP "sudo ipsec status"
ssh -i ~/.ssh/foodhub-key ubuntu@VPN_IP "sudo journalctl -u strongswan-starter -f"

# Restart VPN
ssh -i ~/.ssh/foodhub-key ubuntu@VPN_IP "sudo ipsec restart"
```

---

## 📂 Project Structure

```
DEVSECOPS-HYBRID-CLOUD/
├── manual-deployment/           # 🎯 Scripts (No Terraform!)
│   ├── openstack/              # OpenStack deployment scripts
│   │   ├── 01-create-network.sh
│   │   ├── 02-create-security-groups.sh
│   │   ├── 03-create-vms.sh
│   │   ├── 04-install-harbor.sh
│   │   ├── 05-install-postgresql.sh
│   │   ├── 06-configure-vpn.sh
│   │   ├── 07-install-argocd.sh
│   │   ├── 08-install-prometheus-grafana.sh
│   │   └── 09-configure-harbor-sync.sh
│   ├── kubernetes/             # K8s installation scripts
│   │   ├── 01-install-k8s-master.sh
│   │   └── 02-install-k8s-workers.sh
│   └── aws/                    # AWS deployment scripts
│       ├── 01-create-eks-cluster.sh
│       ├── 02-create-ecr-repos.sh
│       └── 03-create-rds-postgresql.sh
├── k8s/
│   └── deployments/            # Kubernetes manifests
│       ├── base/               # Kustomize base
│       └── overlays/           # Cloud-specific overrides
│           ├── aws/
│           └── openstack/
├── CICD/
│   ├── Jenkinsfile             # Standard pipeline
│   ├── Jenkinsfile.hybrid-cloud # Full hybrid pipeline
│   └── Jenkinsfile.no-terraform # Simplified (No Terraform)
├── services/                   # Microservices source
│   ├── users/
│   ├── products/
│   ├── orders/
│   └── frontend/
├── scripts/                    # Utility scripts
│   └── docker-push-ghcr.sh
├── docker-compose.yml          # Local Jenkins + SonarQube
└── quick-start.sh              # Quick setup script
```

---

## 💡 Tips

1. **Sử dụng tmux/screen** cho các scripts chạy lâu:
   ```bash
   screen -S foodhub-deploy
   ./openstack/03-create-vms.sh
   # Ctrl+A, D to detach
   # screen -r foodhub-deploy to reattach
   ```

2. **Backup configs**:
   ```bash
   mkdir ~/foodhub-configs
   cp /tmp/foodhub-*.sh ~/foodhub-configs/
   ```

3. **Log output**:
   ```bash
   ./script.sh 2>&1 | tee logs/script-output.log
   ```

4. **Scripts idempotent**: Có thể chạy lại an toàn, sẽ skip resources đã tồn tại.

---

## ✅ Success Criteria

- [ ] OpenStack VMs: All running
- [ ] Kubernetes: 3 nodes Ready
- [ ] Harbor: Accessible và có thể push/pull images
- [ ] PostgreSQL: Có thể connect và query
- [ ] Jenkins: Pipeline chạy thành công
- [ ] ArgoCD: Sync applications thành công
- [ ] Grafana: Hiển thị metrics
- [ ] VPN (Hybrid): Tunnels ESTABLISHED
- [ ] Application: Accessible via Ingress

---

**Version**: 1.0.0  
**Author**: Vu Truong Doan  
**Last Updated**: 2026-01-13  
**Status**: ✅ Production Ready (No Terraform!)
