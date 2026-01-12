# 🚀 DevSecOps Hybrid Cloud CI/CD Pipeline

> **Xây dựng và Tối ưu hóa Pipeline CI/CD DevSecOps cho Microservices trên Môi trường Hybrid Cloud (AWS + OpenStack)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](./docker-compose.yml)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Ready-326CE5.svg)](./k8s/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-623CE4.svg)](./terraform/)

---

## 📖 Mục Lục

1. [Giới Thiệu](#-giới-thiệu)
2. [Tính Năng Chính](#-tính-năng-chính)
3. [Kiến Trúc Hệ Thống](#-kiến-trúc-hệ-thống)
4. [Công Nghệ Sử Dụng](#-công-nghệ-sử-dụng)
5. [Cấu Trúc Dự Án](#-cấu-trúc-dự-án)
6. [Hướng Dẫn Cài Đặt](#-hướng-dẫn-cài-đặt)
7. [Chế Độ Triển Khai](#-chế-độ-triển-khai)
8. [Quy Trình CI/CD](#-quy-trình-cicd)
9. [Tính Năng Bảo Mật](#-tính-năng-bảo-mật)
10. [Tài Liệu Tham Khảo](#-tài-liệu-tham-khảo)
11. [Tác Giả](#-tác-giả)

---

## 📌 Giới Thiệu

### Dự án này là gì?

Đây là một dự án **DevSecOps CI/CD Pipeline** hoàn chỉnh, được thiết kế để:

- **Tự động hóa** quá trình build, test, scan bảo mật và deploy ứng dụng
- **Triển khai Hybrid Cloud** - kết hợp AWS (public cloud) và OpenStack (private cloud)
- **Đảm bảo bảo mật** từ đầu đến cuối với các công cụ scan tự động

### Tại sao cần dự án này?

| Vấn đề | Giải pháp |
|--------|-----------|
| Deploy thủ công tốn thời gian | ✅ Pipeline tự động hóa hoàn toàn |
| Lỗi bảo mật không được phát hiện sớm | ✅ Trivy scan + SonarQube kiểm tra liên tục |
| Chỉ dùng 1 cloud, rủi ro cao | ✅ Hybrid Cloud (AWS + OpenStack) |
| Khó theo dõi trạng thái hệ thống | ✅ Prometheus + Grafana monitoring |

---

## ✨ Tính Năng Chính

### 🏢 Multi-Cloud Deployment
```
┌─────────────────┐         ┌─────────────────┐
│   AWS Cloud     │◄───────►│   OpenStack     │
│   (Public)      │   VPN   │   (Private)     │
└─────────────────┘         └─────────────────┘
```
- Deploy lên **AWS EKS** (Elastic Kubernetes Service)
- Deploy lên **OpenStack Kubernetes** (Private Cloud)
- **Đồng bộ** cả 2 môi trường cùng lúc

### 🔄 CI/CD Pipeline Hoàn Chỉnh
- **Jenkins** - Tự động build và deploy
- **ArgoCD** - GitOps deployment
- **SonarQube** - Kiểm tra chất lượng code
- **Trivy** - Scan lỗ hổng bảo mật container

### 🛡️ DevSecOps (Security First)
- Scan bảo mật tự động trong pipeline
- Container image scanning
- Code quality analysis
- Secret management

### 📊 Observability
- **Prometheus** - Thu thập metrics
- **Grafana** - Dashboard trực quan
- Alerting khi có sự cố

---

## 🏗️ Kiến Trúc Hệ Thống

### Tổng Quan Kiến Trúc

```
                        ┌─────────────────────────────────────────┐
                        │              DEVELOPER                   │
                        │           (Git Push Code)                │
                        └──────────────────┬──────────────────────┘
                                           │
                                           ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                              JENKINS CI/CD                                    │
│  ┌─────────┐   ┌──────────┐   ┌──────────┐   ┌─────────┐   ┌──────────────┐ │
│  │  Build  │──►│ SonarQube│──►│  Trivy   │──►│  Push   │──►│ Update GitOps│ │
│  │  Code   │   │  Scan    │   │  Scan    │   │ Images  │   │    Repo      │ │
│  └─────────┘   └──────────┘   └──────────┘   └─────────┘   └──────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
                                           │
                    ┌──────────────────────┴──────────────────────┐
                    ▼                                              ▼
    ┌───────────────────────────┐              ┌───────────────────────────┐
    │      AWS (Public Cloud)   │              │  OpenStack (Private Cloud)│
    │  ┌─────────────────────┐  │              │  ┌─────────────────────┐  │
    │  │      AWS ECR        │  │◄──── VPN ───►│  │      Harbor         │  │
    │  │  (Container Registry)│  │              │  │  (Container Registry)│  │
    │  └─────────────────────┘  │              │  └─────────────────────┘  │
    │  ┌─────────────────────┐  │              │  ┌─────────────────────┐  │
    │  │      AWS EKS        │  │              │  │    Kubernetes       │  │
    │  │  (Kubernetes)       │  │              │  │    Cluster          │  │
    │  └─────────────────────┘  │              │  └─────────────────────┘  │
    │  ┌─────────────────────┐  │              │  ┌─────────────────────┐  │
    │  │     AWS RDS         │  │              │  │    PostgreSQL       │  │
    │  │   (Database)        │  │              │  │    (Primary DB)     │  │
    │  └─────────────────────┘  │              │  └─────────────────────┘  │
    └───────────────────────────┘              └───────────────────────────┘
```

### Microservices

Dự án bao gồm **4 microservices**:

| Service | Mô Tả | Công Nghệ | Port |
|---------|-------|-----------|------|
| **👤 Users** | Quản lý người dùng, đăng ký, đăng nhập | Spring Boot (Java 21) | 8082 |
| **📦 Products** | Quản lý sản phẩm, danh mục | Spring Boot (Java 21) | 8083 |
| **🛒 Orders** | Xử lý đơn hàng, thanh toán | Spring Boot (Java 21) | 8084 |
| **🖥️ Frontend** | Giao diện web cho người dùng | Next.js 14 (React) | 3000 |

---

## 🛠️ Công Nghệ Sử Dụng

### Phân Loại Theo Mục Đích

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           TECH STACK                                        │
├──────────────────┬──────────────────┬──────────────────┬───────────────────┤
│   🐳 CONTAINERS  │    🔄 CI/CD      │   🛡️ SECURITY   │   📊 MONITORING   │
├──────────────────┼──────────────────┼──────────────────┼───────────────────┤
│   Docker         │   Jenkins        │   Trivy          │   Prometheus      │
│   Kubernetes     │   ArgoCD         │   SonarQube      │   Grafana         │
│   ECR/Harbor     │   Git/GitHub     │   Cosign         │   AlertManager    │
└──────────────────┴──────────────────┴──────────────────┴───────────────────┘
                                    │
┌───────────────────────────────────┴────────────────────────────────────────┐
│                          ☁️ CLOUD PLATFORMS                                 │
├────────────────────────────────────┬───────────────────────────────────────┤
│          AWS (Public Cloud)        │       OpenStack (Private Cloud)       │
├────────────────────────────────────┼───────────────────────────────────────┤
│   • EKS (Kubernetes)               │   • Nova (Compute)                    │
│   • ECR (Container Registry)       │   • Neutron (Network)                 │
│   • RDS (Database)                 │   • Cinder (Block Storage)            │
│   • VPN Gateway                    │   • Harbor (Container Registry)       │
│   • ALB (Load Balancer)            │   • PostgreSQL                        │
└────────────────────────────────────┴───────────────────────────────────────┘
```

### Infrastructure as Code

| Tool | Mục Đích |
|------|----------|
| **Terraform** | Tự động tạo hạ tầng trên AWS và OpenStack |
| **Kustomize** | Quản lý Kubernetes manifests cho nhiều môi trường |
| **Helm** | Package manager cho Kubernetes |

---

## 📁 Cấu Trúc Dự Án

```
DEVSECOPS-HYBRID-CLOUD/
│
├── 📂 services/                    # Source code các microservices
│   ├── 👤 users/                   # Service quản lý người dùng
│   ├── 📦 products/                # Service quản lý sản phẩm
│   ├── 🛒 orders/                  # Service xử lý đơn hàng
│   └── 🖥️ frontend/               # Ứng dụng web Next.js
│
├── 📂 CICD/                        # Cấu hình Jenkins Pipeline
│   ├── Jenkinsfile                 # Pipeline cơ bản
│   └── Jenkinsfile.hybrid-cloud    # Pipeline cho hybrid cloud
│
├── 📂 terraform/                   # Infrastructure as Code
│   ├── openstack/                  # Cấu hình OpenStack
│   ├── eks.tf                      # AWS EKS cluster
│   ├── ecr.tf                      # AWS ECR registry
│   ├── vpn.tf                      # VPN giữa AWS-OpenStack
│   └── ...                         # Các file terraform khác
│
├── 📂 k8s/                         # Kubernetes manifests
│   ├── deployments/                # Deployment configs
│   │   ├── base/                   # Config chung
│   │   └── overlays/               # Config riêng mỗi môi trường
│   │       ├── aws/                # AWS-specific
│   │       └── openstack/          # OpenStack-specific
│   ├── argocd/                     # ArgoCD applications
│   └── examples/                   # Ví dụ deployment
│
├── 📂 jenkins/                     # Custom Jenkins Docker image
│   ├── Dockerfile                  # Jenkins với các tool DevSecOps
│   ├── plugins.txt                 # Danh sách plugins cần thiết
│   └── casc.yaml                   # Jenkins Configuration as Code
│
├── 📂 scripts/                     # Scripts tự động hóa
│   ├── docker-build-push.sh        # Build và push images
│   ├── security-scan.sh            # Scan bảo mật
│   └── hybrid-cloud/               # Scripts cho hybrid cloud
│
├── 📂 observability/               # Monitoring & Logging
│   ├── prometheus/                 # Prometheus configs
│   └── grafana/                    # Grafana dashboards
│
├── 📂 docs/                        # Tài liệu hướng dẫn
│   ├── DEPLOYMENT-GUIDE.md         # Hướng dẫn deploy chi tiết
│   └── TROUBLESHOOTING.md          # Xử lý sự cố
│
├── 🐳 docker-compose.yml           # Local development environment
├── 📋 .env.example                 # Template biến môi trường
├── 🚀 quick-start.sh               # Script khởi động nhanh
└── 📄 README.md                    # File này
```

---

## 🚀 Hướng Dẫn Cài Đặt

### Yêu Cầu Hệ Thống

| Phần Mềm | Phiên Bản | Mục Đích |
|----------|-----------|----------|
| Docker | 20.10+ | Chạy containers |
| Docker Compose | 2.0+ | Orchestrate local containers |
| Git | 2.0+ | Version control |
| AWS CLI | 2.0+ | (Optional) Cho AWS deployment |
| kubectl | 1.28+ | (Optional) Kubernetes CLI |

### 🛠️ Cài Đặt Cơ Bản (Jenkins + SonarQube)

```bash
# 1. Clone repository
git clone https://github.com/vutd22uit/DEVSECOPS-HYBRID-CLOUD.git
cd DEVSECOPS-HYBRID-CLOUD

# 2. Chạy quick start script
./quick-start.sh

# 3. Truy cập Jenkins
open http://localhost:8080
# Tài khoản: admin / admin123
```

### 🎬 Demo Toàn Diện (Full Stack)

Nếu bạn muốn chạy thử **toàn bộ microservices** (Frontend + 3 Backend + Database) ngay lập tức:

```bash
# Cấp quyền và chạy demo
chmod +x demo.sh
./demo.sh
```

👉 **Hướng dẫn chi tiết kịch bản Demo:** [docs/DEMO-GUIDE.md](./docs/DEMO-GUIDE.md)

---

### Bước 2: Cấu Hình Môi Trường

**Cách 1: Dùng Quick Start Script (Khuyến nghị)**
```bash
./quick-start.sh
```

**Cách 2: Dùng Docker Compose**
```bash
docker-compose up -d
```

### Bước 4: Truy Cập Các Dịch Vụ

| Dịch Vụ | URL | Tài Khoản |
|---------|-----|-----------|
| **Jenkins** | http://localhost:8080 | admin / admin123 |
| **SonarQube** | http://localhost:9000 | admin / admin |

### Bước 5: Cấu Hình Jenkins Credentials

1. Đăng nhập Jenkins
2. Vào **Manage Jenkins** → **Credentials**
3. Thêm các credentials:
   - AWS Access Key
   - GitHub Token
   - Harbor Registry
   - Kubernetes config

📖 **Xem chi tiết:** [docs/DEPLOYMENT-GUIDE.md](./docs/DEPLOYMENT-GUIDE.md)

---

## 🎯 Chế Độ Triển Khai

Pipeline hỗ trợ **3 chế độ triển khai** khác nhau:

### 1️⃣ AWS Only Mode

```groovy
// Trong Jenkinsfile
DEPLOYMENT_MODE = 'AWS'
```

```
┌──────────────┐      ┌──────────────┐
│   Jenkins    │─────►│   AWS EKS    │
│              │      │   + ECR      │
└──────────────┘      └──────────────┘
```

✅ **Phù hợp khi:** Chỉ cần triển khai trên cloud public

### 2️⃣ OpenStack Only Mode

```groovy
// Trong Jenkinsfile
DEPLOYMENT_MODE = 'OPENSTACK'
```

```
┌──────────────┐      ┌──────────────┐
│   Jenkins    │─────►│  OpenStack   │
│              │      │   + Harbor   │
└──────────────┘      └──────────────┘
```

✅ **Phù hợp khi:** Dữ liệu nhạy cảm, cần on-premises

### 3️⃣ Hybrid Mode (Mặc định)

```groovy
// Trong Jenkinsfile
DEPLOYMENT_MODE = 'HYBRID'
```

```
┌──────────────┐      ┌──────────────┐
│   Jenkins    │─────►│   AWS EKS    │
│              │      └──────────────┘
│              │             │ VPN
│              │             ▼
│              │      ┌──────────────┐
│              │─────►│  OpenStack   │
└──────────────┘      └──────────────┘
```

✅ **Phù hợp khi:** 
- Cần disaster recovery
- Tối ưu chi phí (burst to cloud)
- Yêu cầu data residency

---

## 🔄 Quy Trình CI/CD

### Pipeline Flow Chi Tiết

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CI/CD PIPELINE FLOW                                │
└─────────────────────────────────────────────────────────────────────────────┘

     ① TRIGGER                ② BUILD & TEST              ③ SECURITY
    ┌─────────┐              ┌─────────────┐             ┌───────────┐
    │   Git   │─────────────►│  Checkout   │────────────►│ SonarQube │
    │  Push   │              │  & Build    │             │   Scan    │
    └─────────┘              └─────────────┘             └───────────┘
                                                               │
                                                               ▼
     ⑥ DEPLOY                 ⑤ PUSH IMAGES              ④ CONTAINER SCAN
    ┌─────────────┐          ┌─────────────┐             ┌───────────┐
    │   ArgoCD    │◄─────────│  ECR/Harbor │◄────────────│   Trivy   │
    │   GitOps    │          │   Registry  │             │   Scan    │
    └─────────────┘          └─────────────┘             └───────────┘
          │
          ▼
    ┌─────────────┐
    │ Kubernetes  │
    │   Cluster   │
    └─────────────┘
```

### Các Bước Trong Pipeline

| # | Bước | Mô Tả | Tool |
|---|------|-------|------|
| 1 | **Checkout** | Lấy code từ GitHub | Git |
| 2 | **Build** | Compile code, chạy unit tests | Maven/npm |
| 3 | **Code Analysis** | Kiểm tra chất lượng code | SonarQube |
| 4 | **Build Image** | Tạo Docker image | Docker |
| 5 | **Security Scan** | Scan lỗ hổng bảo mật | Trivy |
| 6 | **Push Image** | Đẩy image lên registry | ECR/Harbor |
| 7 | **Update GitOps** | Cập nhật manifest | Git |
| 8 | **Deploy** | Triển khai tự động | ArgoCD |
| 9 | **Health Check** | Kiểm tra service hoạt động | kubectl |

---

## 🔐 Tính Năng Bảo Mật

### Security-First Approach

```
┌────────────────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                                  │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │   CODE LEVEL    │  │  CONTAINER      │  │   RUNTIME       │    │
│  │                 │  │  LEVEL          │  │   LEVEL         │    │
│  │  • SonarQube    │  │  • Trivy        │  │  • RBAC         │    │
│  │  • SAST         │  │  • Image Sign   │  │  • Network      │    │
│  │  • Dependency   │  │  • Base Image   │  │    Policies     │    │
│  │    Check        │  │    Scan         │  │  • Pod Security │    │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘    │
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐                         │
│  │   SECRETS       │  │   NETWORK       │                         │
│  │   MANAGEMENT    │  │   SECURITY      │                         │
│  │                 │  │                 │                         │
│  │  • K8s Secrets  │  │  • VPN Tunnel   │                         │
│  │  • Jenkins      │  │  • Security     │                         │
│  │    Credentials  │  │    Groups       │                         │
│  └─────────────────┘  └─────────────────┘                         │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

### Chi Tiết Các Tính Năng

| Tính Năng | Công Cụ | Mô Tả |
|-----------|---------|-------|
| **Container Scan** | Trivy | Phát hiện CVE (HIGH/CRITICAL) trong images |
| **Code Quality** | SonarQube | Static Application Security Testing (SAST) |
| **Secret Management** | K8s Secrets | Mã hóa và quản lý secrets |
| **Image Signing** | Cosign | Xác minh nguồn gốc container images |
| **Network Security** | VPN + SG | Bảo vệ traffic giữa các clouds |
| **RBAC** | Kubernetes | Phân quyền truy cập theo role |

---

## 📚 Tài Liệu Tham Khảo

| Tài Liệu | Mô Tả | Link |
|----------|-------|------|
| 📖 **Deployment Guide** | Hướng dẫn triển khai chi tiết | [docs/DEPLOYMENT-GUIDE.md](./docs/DEPLOYMENT-GUIDE.md) |
| 🔧 **Troubleshooting** | Xử lý các lỗi thường gặp | [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) |
| 🌐 **Hybrid Cloud** | Chi tiết kiến trúc hybrid | [HYBRID-CLOUD-DEPLOYMENT.md](./HYBRID-CLOUD-DEPLOYMENT.md) |
| ⚡ **Quick Start** | Bắt đầu nhanh trong 5 phút | [docs/hybrid-cloud/QUICK-START.md](./docs/hybrid-cloud/QUICK-START.md) |

---

## 🤝 Đóng Góp

Mọi đóng góp đều được hoan nghênh! Vui lòng tạo Pull Request hoặc Issue nếu:
- Phát hiện lỗi
- Có ý tưởng cải tiến
- Muốn thêm tính năng mới

---

## 📄 License

Dự án này được phát hành dưới giấy phép **MIT License** - xem file [LICENSE](./LICENSE) để biết thêm chi tiết.

---

## 👨‍💻 Tác Giả

**Vũ Trường Đoàn**

- 🎓 Sinh viên Đại học Công nghệ Thông tin (UIT)
- 📧 GitHub: [@vutd22uit](https://github.com/vutd22uit)

---

## 📊 Trạng Thái Dự Án

| Thành Phần | Trạng Thái |
|------------|------------|
| CI/CD Pipeline | ✅ Hoàn thành |
| Terraform IaC | ✅ Hoàn thành |
| Kubernetes Manifests | ✅ Hoàn thành |
| Security Scanning (SAST + DAST) | ✅ Hoàn thành |
| Hybrid Health Checks | ✅ Hoàn thành |
| Documentation | ✅ Hoàn thành |

**Overall Status:** ✅ **Sẵn sàng Production (Hybrid Ready)**

---

<p align="center">
  <b>⭐ Nếu thấy dự án hữu ích, hãy cho một star nhé! ⭐</b>
</p>
