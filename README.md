# 🚀 DevSecOps Hybrid Cloud CI/CD Pipeline

<div align="center">

![DevSecOps](https://img.shields.io/badge/DevSecOps-Pipeline-blue?style=for-the-badge&logo=jenkins)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Hybrid-326CE5?style=for-the-badge&logo=kubernetes)
![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?style=for-the-badge&logo=amazon-aws)
![OpenStack](https://img.shields.io/badge/OpenStack-Private-ED1944?style=for-the-badge&logo=openstack)

**Xây dựng và Tối ưu Pipeline CI/CD DevSecOps cho Microservices trên Hybrid Cloud (AWS + OpenStack)**

[🚀 Bắt đầu nhanh](#-bắt-đầu-nhanh-30-giây) • [📖 Hướng dẫn chi tiết](#-hướng-dẫn-sử-dụng-chi-tiết) • [🎯 Demo](#-kịch-bản-demo) • [❓ FAQ](#-câu-hỏi-thường-gặp)

</div>

---

## 📋 Mục Lục

1. [Giới thiệu dự án](#-giới-thiệu-dự-án)
2. [Kiến trúc hệ thống](#-kiến-trúc-hệ-thống)
3. [Yêu cầu hệ thống](#-yêu-cầu-hệ-thống)
4. [Bắt đầu nhanh (30 giây)](#-bắt-đầu-nhanh-30-giây)
5. [Hướng dẫn sử dụng chi tiết](#-hướng-dẫn-sử-dụng-chi-tiết)
6. [Cấu trúc dự án](#-cấu-trúc-dự-án)
7. [Kịch bản Demo](#-kịch-bản-demo)
8. [Troubleshooting](#-troubleshooting)
9. [Câu hỏi thường gặp](#-câu-hỏi-thường-gặp)

---

## 🎯 Giới Thiệu Dự Án

### Dự án này là gì?

Đây là một **hệ thống CI/CD DevSecOps hoàn chỉnh** cho phép triển khai ứng dụng microservices lên **cả AWS (Public Cloud) và OpenStack (Private Cloud)** một cách tự động, bảo mật và hiệu quả.

### Tại sao cần Hybrid Cloud?

| Vấn đề | Giải pháp Hybrid Cloud |
|--------|------------------------|
| 🔒 Dữ liệu nhạy cảm cần lưu nội bộ | → Private Cloud (OpenStack) |
| 🌍 Cần scale nhanh khi traffic tăng | → Public Cloud (AWS) |
| 💰 Chi phí cao khi chỉ dùng Public | → Tối ưu 40-60% chi phí |
| 🛡️ Quy định về bảo mật dữ liệu | → Tuân thủ với Private Cloud |

### Dự án bao gồm những gì?

```
┌──────────────────────────────────────────────────────────────────┐
│                    FoodHub - Ứng Dụng Demo                       │
├──────────────────────────────────────────────────────────────────┤
│  👤 Users Service    │  📦 Products Service  │  📋 Orders Service│
│  (Quản lý user)      │  (Quản lý sản phẩm)   │  (Quản lý đơn)    │
├──────────────────────────────────────────────────────────────────┤
│                    🖥️ Frontend (Next.js)                         │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Kiến Trúc Hệ Thống

```
                              ┌─────────────────┐
                              │   👨‍💻 Developer  │
                              │   Push Code     │
                              └────────┬────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │    🔧 Jenkins   │
                              │   CI/CD Server  │
                              └────────┬────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    │                  │                  │
                    ▼                  ▼                  ▼
           ┌───────────────┐  ┌───────────────┐  ┌───────────────┐
           │ 🔍 SonarQube  │  │ 🛡️ Trivy      │  │ 🐳 Docker     │
           │ Code Quality  │  │ Security Scan │  │ Build Image   │
           └───────────────┘  └───────────────┘  └───────┬───────┘
                                                         │
                              ┌───────────────────────────┴───────────────────────────┐
                              │                   Image Registry                       │
                              │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
                              │  │ 📦 ECR      │  │ 🏠 Harbor   │  │ 🐙 GHCR    │    │
                              │  │ (AWS)       │  │ (OpenStack) │  │ (GitHub)   │    │
                              │  └─────────────┘  └─────────────┘  └─────────────┘    │
                              └───────────────────────────┬───────────────────────────┘
                                                          │
                                                          ▼
                              ┌─────────────────────────────────────────────────────────┐
                              │                      🔄 ArgoCD                          │
                              │                   GitOps Controller                      │
                              └────────────────────────┬────────────────────────────────┘
                                                       │
                    ┌──────────────────────────────────┴──────────────────────────────────┐
                    │                                                                      │
                    ▼                                                                      ▼
    ┌───────────────────────────────────┐              ┌───────────────────────────────────┐
    │        ☁️ AWS (Public Cloud)       │              │      🏢 OpenStack (Private)       │
    │  ┌─────────────────────────────┐  │              │  ┌─────────────────────────────┐  │
    │  │      EKS Cluster            │  │     VPN      │  │    Kubernetes Cluster       │  │
    │  │  ┌───┐ ┌───┐ ┌───┐ ┌───┐   │  │◄────────────►│  │  ┌───┐ ┌───┐ ┌───┐ ┌───┐   │  │
    │  │  │ U │ │ P │ │ O │ │ F │   │  │              │  │  │ U │ │ P │ │ O │ │ F │   │  │
    │  │  └───┘ └───┘ └───┘ └───┘   │  │              │  │  └───┘ └───┘ └───┘ └───┘   │  │
    │  └─────────────────────────────┘  │              │  └─────────────────────────────┘  │
    │  ┌─────────────────────────────┐  │              │  ┌─────────────────────────────┐  │
    │  │      RDS PostgreSQL         │  │              │  │    PostgreSQL (VM)          │  │
    │  └─────────────────────────────┘  │              │  └─────────────────────────────┘  │
    └───────────────────────────────────┘              └───────────────────────────────────┘
```

**Chú thích:** U = Users, P = Products, O = Orders, F = Frontend

---

## 💻 Yêu Cầu Hệ Thống

### Máy tính của bạn cần có:

| Tool | Phiên bản | Mục đích | Cách cài đặt |
|------|-----------|----------|--------------|
| **Docker** | 20.10+ | Chạy containers | [Tải Docker Desktop](https://www.docker.com/products/docker-desktop/) |
| **Git** | 2.30+ | Quản lý source code | `brew install git` (Mac) hoặc [Tải Git](https://git-scm.com/) |

### (Tùy chọn) Nếu muốn deploy lên Cloud:

| Tool | Mục đích | Cách cài đặt |
|------|----------|--------------|
| **kubectl** | Quản lý Kubernetes | `brew install kubectl` |
| **AWS CLI** | Quản lý AWS | `brew install awscli` |
| **eksctl** | Tạo EKS cluster | `brew install eksctl` |
| **Helm** | Cài đặt packages K8s | `brew install helm` |

---

## 🚀 Bắt Đầu Nhanh (30 giây)

### Bước 1: Clone dự án

```bash
git clone https://github.com/vutd22uit/DEVSECOPS-HYBRID-CLOUD.git
cd DEVSECOPS-HYBRID-CLOUD
```

### Bước 2: Chạy Quick Start

```bash
./quick-start.sh
```

### Bước 3: Mở trình duyệt

| Service | URL | Tài khoản |
|---------|-----|-----------|
| 🔧 **Jenkins** | http://localhost:8080 | admin / admin123 |
| 📊 **SonarQube** | http://localhost:9000 | admin / admin |

**🎉 Vậy là xong! Jenkins và SonarQube đã chạy.**

---

## 📖 Hướng Dẫn Sử Dụng Chi Tiết

### Phần 1: Chạy CI/CD Pipeline Local

#### 1.1. Cấu hình Jenkins Credentials

Sau khi Jenkins khởi động, bạn cần thêm các credentials:

1. Mở Jenkins: http://localhost:8080
2. Đăng nhập: `admin` / `admin123`
3. Vào **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
4. Thêm các credentials sau:

| ID | Loại | Giá trị |
|----|------|---------|
| `github-pat` | Secret text | GitHub Personal Access Token |
| `sonar-token` | Secret text | SonarQube Token (lấy từ http://localhost:9000) |

#### 1.2. Tạo Pipeline mới

1. Click **New Item**
2. Nhập tên: `FoodHub-Pipeline`
3. Chọn **Pipeline** → **OK**
4. Trong phần **Pipeline**:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `https://github.com/vutd22uit/DEVSECOPS-HYBRID-CLOUD.git`
   - **Script Path**: `CICD/Jenkinsfile.no-terraform`
5. Click **Save**
6. Click **Build Now**

#### 1.3. Xem kết quả

Pipeline sẽ thực hiện:
- ✅ **Build** các microservices
- ✅ **Scan** code với SonarQube
- ✅ **Scan** security với Trivy
- ✅ **Push** images lên registry

---

### Phần 2: Deploy lên OpenStack (Private Cloud)

> ⚠️ **Yêu cầu**: Bạn cần có môi trường OpenStack sẵn

#### 2.1. Cấu hình OpenStack CLI

```bash
# Tạo file environment
cat > ~/.openstack-foodhub.env << 'EOF'
export OS_AUTH_URL="http://your-openstack:5000/v3"
export OS_USERNAME="admin"
export OS_PASSWORD="your-password"
export OS_PROJECT_NAME="foodhub"
export OS_USER_DOMAIN_NAME="Default"
export OS_PROJECT_DOMAIN_NAME="Default"
EOF

# Load environment
source ~/.openstack-foodhub.env

# Kiểm tra kết nối
openstack token issue
```

#### 2.2. Tạo Infrastructure

```bash
cd manual-deployment

# Bước 1: Tạo Network (2 phút)
./openstack/01-create-network.sh

# Bước 2: Tạo Security Groups (1 phút)
./openstack/02-create-security-groups.sh

# Bước 3: Tạo Virtual Machines (15-20 phút)
./openstack/03-create-vms.sh
```

#### 2.3. Cài đặt Kubernetes

```bash
# Bước 4: Cài K8s Master (10 phút)
./kubernetes/01-install-k8s-master.sh

# Bước 5: Cài K8s Workers (10 phút)
./kubernetes/02-install-k8s-workers.sh

# Kiểm tra cluster
kubectl get nodes
# Kết quả mong đợi: 3 nodes (1 master + 2 workers)
```

#### 2.4. Cài đặt các Services

```bash
# Harbor Registry
./openstack/04-install-harbor.sh

# ArgoCD (GitOps)
./openstack/07-install-argocd.sh

# Prometheus + Grafana (Monitoring)
./openstack/08-install-prometheus-grafana.sh
```

#### 2.5. Deploy ứng dụng

```bash
# Deploy bằng Kustomize
kubectl apply -k k8s/deployments/overlays/openstack/

# Kiểm tra pods
kubectl get pods -n foodhub
```

---

### Phần 3: Deploy lên AWS (Public Cloud)

> ⚠️ **Yêu cầu**: Bạn cần có tài khoản AWS với quyền admin

#### 3.1. Cấu hình AWS CLI

```bash
aws configure
# Nhập: AWS Access Key ID
# Nhập: AWS Secret Access Key
# Nhập: Region (ap-southeast-1)
# Nhập: Output format (json)

# Kiểm tra
aws sts get-caller-identity
```

#### 3.2. Tạo EKS Cluster

```bash
cd manual-deployment/aws

# Tạo EKS cluster (15-20 phút)
./01-create-eks-cluster.sh

# Kết nối kubectl với EKS
aws eks update-kubeconfig --name foodhub-eks --region ap-southeast-1

# Kiểm tra
kubectl get nodes
```

#### 3.3. Tạo ECR Repositories

```bash
./02-create-ecr-repos.sh
```

#### 3.4. Tạo RDS PostgreSQL

```bash
./03-create-rds-postgresql.sh
```

#### 3.5. Deploy ứng dụng

```bash
kubectl apply -k k8s/deployments/overlays/aws/
```

---

### Phần 4: Thiết lập Hybrid Cloud (AWS + OpenStack)

#### 4.1. Kết nối VPN giữa 2 Cloud

```bash
# Trên AWS
cd manual-deployment/aws
./01-create-vpn.sh

# Trên OpenStack
cd manual-deployment/openstack
./06-configure-vpn.sh
```

#### 4.2. Cấu hình Harbor Sync với ECR

```bash
./openstack/09-configure-harbor-sync.sh
```

#### 4.3. Cấu hình ArgoCD Multi-cluster

```bash
# Đăng ký cả 2 clusters với ArgoCD
argocd cluster add aws-eks --name aws-production
argocd cluster add openstack-k8s --name openstack-production
```

---

## 📁 Cấu Trúc Dự Án

```
DEVSECOPS-HYBRID-CLOUD/
│
├── 📂 services/                    # Source code các microservices
│   ├── users/                      # 👤 Service quản lý users (Java Spring Boot)
│   ├── products/                   # 📦 Service quản lý products (Java Spring Boot)
│   ├── orders/                     # 📋 Service quản lý orders (Java Spring Boot)
│   └── frontend/                   # 🖥️ Web UI (Next.js React)
│
├── 📂 CICD/                        # CI/CD Pipelines
│   ├── Jenkinsfile                 # Pipeline cơ bản
│   ├── Jenkinsfile.hybrid-cloud    # Pipeline đầy đủ cho Hybrid
│   └── Jenkinsfile.no-terraform    # Pipeline không dùng Terraform
│
├── 📂 k8s/                         # Kubernetes manifests
│   ├── deployments/
│   │   ├── base/                   # Base manifests (Kustomize)
│   │   └── overlays/
│   │       ├── aws/                # AWS-specific configs
│   │       └── openstack/          # OpenStack-specific configs
│   └── argocd/                     # ArgoCD configurations
│
├── 📂 manual-deployment/           # 🎯 Scripts triển khai thủ công (No Terraform!)
│   ├── aws/                        # AWS scripts (EKS, ECR, RDS)
│   ├── openstack/                  # OpenStack scripts (Network, VMs, Harbor)
│   └── kubernetes/                 # K8s installation scripts
│
├── 📂 observability/               # Monitoring configs
│   └── prometheus-federation.yaml  # Prometheus cho Hybrid Cloud
│
├── 📂 docs/                        # 📖 Tài liệu
│   ├── NO-TERRAFORM-GUIDE.md       # Hướng dẫn deploy không Terraform
│   ├── DEMO-SCENARIO.md            # Kịch bản demo 5 phút
│   └── TROUBLESHOOTING.md          # Xử lý lỗi thường gặp
│
├── docker-compose.yml              # Chạy Jenkins + SonarQube local
├── quick-start.sh                  # Script khởi động nhanh
└── README.md                       # 📄 File này!
```

---

## 🎯 Kịch Bản Demo

### Demo 5 phút cho Ban Giám Khảo

| Thời gian | Hoạt động | "Wow" Factor |
|-----------|-----------|--------------|
| 0:00-0:30 | Show infrastructure scripts | "Tạo cả cluster chỉ 1 lệnh" |
| 0:30-1:30 | Push code → Jenkins Pipeline | "Auto security scan + multi-registry" |
| 1:30-2:30 | ArgoCD sync | "GitOps: Self-healing deployment" |
| 2:30-3:30 | Grafana Dashboard | "Unified monitoring cả 2 clouds" |
| 3:30-4:30 | Kill pod demo | "Auto-recovery trong 5 giây" |
| 4:30-5:00 | Show Frontend App | "App chạy mượt mà" |

👉 **Chi tiết**: Xem [docs/DEMO-SCENARIO.md](docs/DEMO-SCENARIO.md)

---

## 🔧 Troubleshooting

### Lỗi thường gặp và cách khắc phục:

#### ❌ Jenkins không khởi động được

```bash
# Kiểm tra logs
docker logs jenkins

# Thử restart
docker-compose down
docker-compose up -d
```

#### ❌ Không kết nối được OpenStack

```bash
# Kiểm tra environment
env | grep OS_

# Load lại environment
source ~/.openstack-foodhub.env

# Test token
openstack token issue
```

#### ❌ Pods ở trạng thái CrashLoopBackOff

```bash
# Xem logs
kubectl logs <pod-name> -n foodhub

# Xem events
kubectl describe pod <pod-name> -n foodhub
```

#### ❌ ArgoCD sync failed

```bash
# Xem chi tiết
argocd app get <app-name>

# Force sync
argocd app sync <app-name> --force
```

👉 **Xem thêm**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## ❓ Câu Hỏi Thường Gặp

### Q1: Tôi cần có OpenStack/AWS thật mới chạy được?

**A**: Không! Bạn có thể chạy Jenkins + SonarQube local bằng `./quick-start.sh`. Chỉ cần Docker là đủ.

### Q2: Terraform ở đâu?

**A**: Dự án này hỗ trợ **2 cách** triển khai:
- 🔧 **Manual Scripts** (Khuyên dùng): Dễ hiểu, dễ debug
- 📦 **Terraform**: Có trong thư mục `/terraform`

### Q3: Chi phí AWS ước tính bao nhiêu?

**A**: Với cấu hình demo:
- EKS: ~$73/tháng (cluster fee)
- EC2 (3 nodes t3.medium): ~$90/tháng
- RDS (db.t3.micro): ~$15/tháng
- **Tổng**: ~$180/tháng

### Q4: Làm sao để contribute?

**A**: 
1. Fork repository
2. Tạo branch mới
3. Commit changes
4. Tạo Pull Request

---

## 📞 Liên Hệ & Hỗ Trợ

- **Author**: Vu Truong Doan
- **Email**: vutd22uit@example.com
- **GitHub**: [@vutd22uit](https://github.com/vutd22uit)

---

## 📜 License

MIT License - Xem file [LICENSE](LICENSE) để biết thêm chi tiết.

---

<div align="center">

**⭐ Nếu dự án hữu ích, hãy cho một Star nhé! ⭐**

Made with ❤️ by Vu Truong Doan

</div>
