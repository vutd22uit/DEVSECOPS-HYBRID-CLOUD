# 🏗️ Enterprise DevSecOps Hybrid Cloud Architecture

## Tổng Quan Hệ Thống

Hệ thống này triển khai kiến trúc **DevSecOps Hybrid Cloud** kết hợp giữa **AWS (Public Cloud)** và **OpenStack (Private Cloud)**, sử dụng mô hình **Hub-and-Spoke** với control plane CI/CD tập trung.

---

## 1. High-Level Architecture Overview

```mermaid
flowchart TB
    subgraph DEV["👨‍💻 DEVELOPMENT LAYER"]
        Developer["Developer<br/>IDE/Git"]
        GitHub["GitHub Repository<br/>Source Code + GitOps"]
    end

    subgraph CICD["⚙️ CI/CD CONTROL PLANE"]
        direction TB
        Jenkins["Jenkins CI Server<br/>Pipeline Orchestration"]
        SonarQube["SonarQube<br/>Code Quality & SAST"]
        Trivy["Trivy Scanner<br/>Container Security"]
        
        subgraph REGISTRY["📦 Container Registries"]
            ECR["AWS ECR<br/>Public Registry"]
            Harbor["Harbor Registry<br/>Private Registry"]
            GHCR["GitHub Container<br/>Registry"]
        end
    end

    subgraph GITOPS["🔄 GitOps Layer"]
        ArgoCD["ArgoCD<br/>Continuous Deployment"]
        ConfigRepo["GitOps Config Repo<br/>Kubernetes Manifests"]
    end

    subgraph AWS["☁️ AWS PUBLIC CLOUD"]
        direction TB
        subgraph AWS_NET["VPC Network"]
            ALB["Application<br/>Load Balancer"]
            EKS["EKS Cluster<br/>Kubernetes v1.28"]
        end
        RDS[("RDS PostgreSQL<br/>Managed Database")]
        ECR2["ECR Registry"]
    end

    subgraph OS["🏢 OPENSTACK PRIVATE CLOUD"]
        direction TB
        subgraph OS_NET["Private Network"]
            NGINX["NGINX<br/>Ingress Controller"]
            K8S["Kubernetes Cluster<br/>Kubeadm"]
        end
        PSQL[("PostgreSQL VM<br/>Self-Managed DB")]
        Harbor2["Harbor Registry"]
    end

    subgraph VPN["🔐 Hybrid Connectivity"]
        VPNGW["Site-to-Site VPN<br/>IPSec Tunnel"]
    end

    subgraph OBS["📊 OBSERVABILITY"]
        Prometheus["Prometheus<br/>Metrics Collection"]
        Grafana["Grafana<br/>Visualization"]
    end

    Developer -->|"1. Push Code"| GitHub
    GitHub -->|"2. Webhook Trigger"| Jenkins
    Jenkins -->|"3. Code Analysis"| SonarQube
    Jenkins -->|"4. Security Scan"| Trivy
    Jenkins -->|"5. Build & Push"| REGISTRY
    Jenkins -->|"6. Update Manifests"| ConfigRepo
    
    ConfigRepo -->|"GitOps Sync"| ArgoCD
    ArgoCD -->|"Deploy to AWS"| EKS
    ArgoCD -->|"Deploy to OpenStack"| K8S

    ECR -.->|"Image Sync"| Harbor
    
    AWS_NET <-->|"Encrypted Traffic"| VPNGW
    VPNGW <-->|"Encrypted Traffic"| OS_NET
    
    EKS --> RDS
    K8S --> PSQL
    
    EKS --> Prometheus
    K8S --> Prometheus
    Prometheus --> Grafana

    classDef aws fill:#FF9900,stroke:#232F3E,color:#232F3E
    classDef openstack fill:#ED1944,stroke:#1A1A1A,color:white
    classDef cicd fill:#335061,stroke:#1A1A1A,color:white
    classDef gitops fill:#FE8019,stroke:#1A1A1A,color:white
    classDef security fill:#6699CC,stroke:#1A1A1A,color:white
    
    class AWS,ALB,EKS,RDS,ECR2 aws
    class OS,NGINX,K8S,PSQL,Harbor2 openstack
    class Jenkins,SonarQube cicd
    class ArgoCD,ConfigRepo gitops
    class Trivy security
```

---

## 2. CI/CD Pipeline Flow (Chi Tiết)

```mermaid
flowchart LR
    subgraph TRIGGER["📥 Trigger"]
        GIT["Git Push<br/>main branch"]
        WEBHOOK["GitHub Webhook"]
    end

    subgraph CI["🔨 Continuous Integration"]
        direction TB
        INIT["Stage 1: Initialize<br/>• Setup Environment<br/>• Login Registries"]
        
        subgraph PARALLEL["Parallel Processing"]
            direction LR
            subgraph SVC1["Users Service"]
                U1["Code Analysis"]
                U2["Security Scan"]
                U3["Build & Push"]
                U4["Image Scan"]
            end
            subgraph SVC2["Products Service"]
                P1["Code Analysis"]
                P2["Security Scan"]
                P3["Build & Push"]
                P4["Image Scan"]
            end
            subgraph SVC3["Orders Service"]
                O1["Code Analysis"]
                O2["Security Scan"]
                O3["Build & Push"]
                O4["Image Scan"]
            end
            subgraph SVC4["Frontend Service"]
                F1["Code Analysis"]
                F2["Security Scan"]
                F3["Build & Push"]
                F4["Image Scan"]
            end
        end
    end

    subgraph CD["🚀 Continuous Deployment"]
        GITOPS["Update GitOps Repo"]
        
        subgraph DEPLOY["Parallel Deployment"]
            AWS_DEPLOY["Deploy → AWS EKS"]
            OS_DEPLOY["Deploy → OpenStack K8s"]
        end
        
        HEALTH["Health Check<br/>kubectl rollout status"]
    end

    GIT --> WEBHOOK --> INIT
    INIT --> PARALLEL
    PARALLEL --> GITOPS
    GITOPS --> DEPLOY
    DEPLOY --> HEALTH

    style TRIGGER fill:#4A90A4,color:white
    style CI fill:#5C6BC0,color:white
    style CD fill:#26A69A,color:white
```

---

## 3. Security Architecture (Shift-Left Security)

```mermaid
flowchart TB
    subgraph SEC["🛡️ SECURITY LAYERS"]
        direction TB
        
        subgraph L1["Layer 1: Code Security"]
            SAST["SonarQube SAST<br/>Static Analysis"]
            LINT["Code Linting<br/>ESLint / Checkstyle"]
        end
        
        subgraph L2["Layer 2: Dependency Security"]
            DEP["Dependency Scan<br/>Trivy fs"]
            LICENSE["License Check"]
        end
        
        subgraph L3["Layer 3: Container Security"]
            IMAGE["Image Vulnerability Scan<br/>Trivy image"]
            SBOM["SBOM Generation"]
        end
        
        subgraph L4["Layer 4: Runtime Security"]
            NETPOL["Network Policies<br/>Zero-Trust"]
            SECRETS["K8s Secrets<br/>Encrypted at Rest"]
            RBAC["RBAC Policies"]
        end
        
        subgraph L5["Layer 5: Infrastructure Security"]
            VPN["VPN Encryption<br/>IPSec/IKE"]
            TLS["TLS Termination<br/>Ingress"]
            SG["Security Groups<br/>Firewall Rules"]
        end
    end

    DEV["Developer Code"] --> L1
    L1 -->|"Pass"| L2
    L2 -->|"Pass"| L3
    L3 -->|"Pass"| L4
    L4 -->|"Deploy"| L5
    
    L1 -->|"Fail: Block Pipeline"| ALERT["🚨 Alert"]
    L3 -->|"CRITICAL CVE"| ALERT

    style SEC fill:#1A237E,color:white
    style ALERT fill:#C62828,color:white
```

---

## 4. Microservices Architecture

```mermaid
flowchart TB
    subgraph CLIENT["🌐 Client Layer"]
        WEB["Web Browser"]
        MOBILE["Mobile App"]
    end

    subgraph INGRESS["🚪 Ingress Layer"]
        ALB["AWS ALB<br/>+ WAF"]
        NGINX["NGINX Ingress"]
    end

    subgraph APP["📱 Application Layer (Kubernetes)"]
        subgraph FRONTEND["Frontend Pod"]
            NEXT["Next.js App<br/>Port: 3000"]
        end
        
        subgraph BACKEND["Backend Services"]
            USERS["Users Service<br/>Spring Boot<br/>Port: 8081"]
            PRODUCTS["Products Service<br/>Spring Boot<br/>Port: 8082"]
            ORDERS["Orders Service<br/>Spring Boot<br/>Port: 8083"]
        end
    end

    subgraph DATA["💾 Data Layer"]
        subgraph AWS_DB["AWS"]
            RDS[("RDS PostgreSQL<br/>Multi-AZ")]
        end
        subgraph OS_DB["OpenStack"]
            PSQL[("PostgreSQL<br/>VM-based")]
        end
    end

    CLIENT --> INGRESS
    INGRESS --> FRONTEND
    FRONTEND -->|"REST API"| BACKEND
    
    USERS -->|"JDBC"| AWS_DB
    USERS -->|"JDBC"| OS_DB
    PRODUCTS -->|"JDBC"| AWS_DB
    PRODUCTS -->|"JDBC"| OS_DB
    ORDERS -->|"JDBC"| AWS_DB
    ORDERS -->|"JDBC"| OS_DB

    style CLIENT fill:#42A5F5,color:white
    style INGRESS fill:#7E57C2,color:white
    style APP fill:#26A69A,color:white
    style DATA fill:#EF5350,color:white
```

---

## 5. Infrastructure as Code (Terraform)

```mermaid
flowchart TB
    subgraph TF["🏗️ TERRAFORM INFRASTRUCTURE"]
        direction TB
        
        subgraph AWS_TF["AWS Resources"]
            VPC["network.tf<br/>VPC + Subnets"]
            EKS_TF["eks.tf<br/>EKS Cluster"]
            RDS_TF["database.tf<br/>RDS PostgreSQL"]
            ECR_TF["ecr.tf<br/>Container Registry"]
            IAM_TF["iam.tf<br/>IAM Roles"]
            SG_TF["security.tf<br/>Security Groups"]
            MON_TF["monitoring.tf<br/>CloudWatch"]
        end
        
        subgraph HYBRID_TF["Hybrid Resources"]
            VPN_TF["vpn.tf<br/>Site-to-Site VPN"]
            ARGO_TF["argocd.tf<br/>GitOps Setup"]
        end
        
        subgraph OS_TF["OpenStack Resources"]
            OS_NET["network.tf<br/>Private Network"]
            OS_COMPUTE["compute.tf<br/>K8s Nodes"]
            OS_HARBOR["harbor.tf<br/>Registry"]
            OS_LB["loadbalancer.tf"]
        end
    end

    subgraph STATE["📂 State Management"]
        S3["S3 Backend<br/>terraform.tfstate"]
        LOCK["DynamoDB<br/>State Locking"]
    end

    TF --> STATE

    style AWS_TF fill:#FF9900,color:#232F3E
    style HYBRID_TF fill:#9C27B0,color:white
    style OS_TF fill:#ED1944,color:white
```

---

## 6. GitOps Deployment Model

```mermaid
flowchart LR
    subgraph SOURCE["📁 Source Repos"]
        APP_REPO["Application Repo<br/>github.com/vutd22uit/<br/>DEVSECOPS-HYBRID-CLOUD"]
        CONFIG_REPO["Config Repo<br/>github.com/NgHVu/<br/>dacn-config"]
    end

    subgraph JENKINS["Jenkins"]
        BUILD["Build Image"]
        UPDATE["Update Manifests"]
    end

    subgraph ARGOCD["ArgoCD Controller"]
        SYNC["Sync Engine"]
        DIFF["Diff Calculator"]
    end

    subgraph CLUSTERS["Kubernetes Clusters"]
        subgraph AWS_K8S["AWS EKS"]
            AWS_NS["Namespace: foodhub"]
        end
        subgraph OS_K8S["OpenStack K8s"]
            OS_NS["Namespace: foodhub"]
        end
    end

    APP_REPO -->|"Code Change"| BUILD
    BUILD -->|"New Image Tag"| UPDATE
    UPDATE -->|"Git Push"| CONFIG_REPO
    
    CONFIG_REPO -->|"Watch"| ARGOCD
    ARGOCD -->|"Apply Manifests"| AWS_K8S
    ARGOCD -->|"Apply Manifests"| OS_K8S

    style SOURCE fill:#24292E,color:white
    style ARGOCD fill:#FE8019,color:black
    style CLUSTERS fill:#326CE5,color:white
```

---

## 7. Observability Stack

```mermaid
flowchart TB
    subgraph SOURCES["📊 Metrics Sources"]
        AWS_PODS["AWS EKS Pods"]
        OS_PODS["OpenStack Pods"]
        JENKINS_M["Jenkins Metrics"]
    end

    subgraph COLLECT["📥 Collection Layer"]
        PROM_AWS["Prometheus<br/>AWS Cluster"]
        PROM_OS["Prometheus<br/>OpenStack Cluster"]
    end

    subgraph FEDERATE["🔗 Federation"]
        PROM_FED["Prometheus Federation<br/>Central Aggregator"]
    end

    subgraph VISUALIZE["📈 Visualization"]
        GRAFANA["Grafana<br/>Unified Dashboards"]
        
        subgraph DASHBOARDS["Dashboards"]
            D1["Cluster Overview"]
            D2["Service Metrics"]
            D3["Pipeline Status"]
            D4["Security Alerts"]
        end
    end

    subgraph ALERT["🚨 Alerting"]
        ALERTMGR["Alertmanager"]
        SLACK["Slack"]
        EMAIL["Email"]
    end

    SOURCES --> COLLECT
    COLLECT --> FEDERATE
    FEDERATE --> VISUALIZE
    GRAFANA --> DASHBOARDS
    FEDERATE --> ALERTMGR
    ALERTMGR --> SLACK
    ALERTMGR --> EMAIL

    style COLLECT fill:#E6522C,color:white
    style VISUALIZE fill:#F46800,color:white
    style ALERT fill:#C62828,color:white
```

---

## 8. Network Architecture

```mermaid
flowchart TB
    subgraph INTERNET["🌐 Internet"]
        USERS_EXT["External Users"]
    end

    subgraph AWS_VPC["AWS VPC (10.0.0.0/16)"]
        subgraph PUB_SUB["Public Subnets"]
            ALB["ALB"]
            NAT["NAT Gateway"]
        end
        
        subgraph PRIV_SUB["Private Subnets"]
            EKS_NODES["EKS Worker Nodes<br/>10.0.1.0/24 - 10.0.3.0/24"]
        end
        
        subgraph DB_SUB["Database Subnets"]
            RDS_INST["RDS Instance<br/>10.0.10.0/24"]
        end
        
        VGW["Virtual Private<br/>Gateway"]
    end

    subgraph VPN_TUNNEL["🔐 VPN Tunnel (IPSec)"]
        TUNNEL["Encrypted Connection"]
    end

    subgraph OS_NET["OpenStack Network (192.168.0.0/16)"]
        subgraph OS_PUB["Public Network"]
            FIP["Floating IPs"]
        end
        
        subgraph OS_PRIV["Private Network"]
            K8S_NODES["K8s Nodes<br/>192.168.1.0/24"]
            DB_VM["PostgreSQL VM<br/>192.168.2.0/24"]
        end
        
        VPN_INST["VPN Instance"]
    end

    INTERNET --> ALB
    ALB --> EKS_NODES
    EKS_NODES --> RDS_INST
    
    VGW <--> TUNNEL <--> VPN_INST
    
    EKS_NODES <-.->|"Cross-Cloud Traffic"| K8S_NODES
    
    INTERNET --> FIP
    FIP --> K8S_NODES
    K8S_NODES --> DB_VM

    style AWS_VPC fill:#FF9900,color:#232F3E
    style VPN_TUNNEL fill:#9C27B0,color:white
    style OS_NET fill:#ED1944,color:white
```

---

## 9. Data Flow Diagram

```mermaid
sequenceDiagram
    autonumber
    participant Dev as 👨‍💻 Developer
    participant GH as GitHub
    participant JK as Jenkins
    participant SQ as SonarQube
    participant TV as Trivy
    participant REG as Registry
    participant ARGO as ArgoCD
    participant K8S as Kubernetes
    participant DB as Database

    Dev->>GH: git push origin main
    GH->>JK: Webhook Trigger
    
    rect rgb(100, 100, 180)
        Note over JK,TV: CI Phase
        JK->>JK: Initialize Environment
        JK->>SQ: Code Quality Analysis
        SQ-->>JK: Quality Gate Result
        JK->>TV: Security Scan (Code + Deps)
        TV-->>JK: Vulnerability Report
    end
    
    rect rgb(100, 180, 100)
        Note over JK,REG: Build Phase
        JK->>JK: Docker Build
        JK->>TV: Image Vulnerability Scan
        TV-->>JK: Image Scan Result
        JK->>REG: Push Image (ECR + Harbor)
    end
    
    rect rgb(180, 100, 100)
        Note over JK,K8S: CD Phase
        JK->>GH: Update GitOps Manifests
        GH-->>ARGO: Manifest Change Detected
        ARGO->>K8S: Apply to AWS EKS
        ARGO->>K8S: Apply to OpenStack K8s
        K8S->>DB: Service Connects
    end
    
    K8S-->>Dev: Deployment Complete ✅
```

---

## 10. Technology Stack Summary

| Layer | AWS | OpenStack | Shared |
|-------|-----|-----------|--------|
| **Compute** | EKS (Managed K8s) | Kubeadm K8s | - |
| **Network** | VPC + ALB | Neutron + NGINX | Site-to-Site VPN |
| **Storage** | EBS + S3 | Cinder | - |
| **Database** | RDS PostgreSQL | PostgreSQL VM | - |
| **Registry** | ECR | Harbor | GHCR |
| **CI/CD** | - | - | Jenkins |
| **GitOps** | - | - | ArgoCD |
| **Security** | - | - | Trivy, SonarQube |
| **Monitoring** | CloudWatch | - | Prometheus + Grafana |
| **IaC** | Terraform AWS | Terraform OpenStack | - |

---

## 11. Deployment Modes

```mermaid
flowchart LR
    subgraph MODES["🔀 Deployment Modes"]
        direction TB
        
        subgraph MODE1["AWS Only"]
            A1["ECR Registry"]
            A2["EKS Cluster"]
            A3["RDS Database"]
        end
        
        subgraph MODE2["OpenStack Only"]
            O1["Harbor Registry"]
            O2["Kubeadm K8s"]
            O3["PostgreSQL VM"]
        end
        
        subgraph MODE3["Hybrid (Default)"]
            H1["Both Registries"]
            H2["Both Clusters"]
            H3["VPN Connected"]
        end
    end

    ENV["DEPLOYMENT_MODE<br/>Environment Variable"] --> MODES

    style MODE1 fill:#FF9900,color:#232F3E
    style MODE2 fill:#ED1944,color:white
    style MODE3 fill:#9C27B0,color:white
```

---

## Kết Luận

Kiến trúc này đáp ứng các yêu cầu enterprise:

1. **High Availability**: Multi-cloud deployment với failover
2. **Security**: Shift-Left với multiple security layers
3. **Scalability**: Kubernetes auto-scaling trên cả 2 clouds
4. **Compliance**: Private cloud cho data sovereignty
5. **Automation**: GitOps với ArgoCD, IaC với Terraform
6. **Observability**: Unified monitoring với Prometheus Federation

---

*Diagram được tạo cho dự án [DEVSECOPS-HYBRID-CLOUD](file:///Users/vutruongdoan/1/DEVSECOPS-HYBRID-CLOUD)*
