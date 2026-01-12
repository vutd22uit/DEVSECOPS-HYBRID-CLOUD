# 🌐 FoodHub Hybrid Cloud Architecture (OpenStack + AWS)

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Deployment Guide](#deployment-guide)
5. [Configuration](#configuration)
6. [Monitoring & Observability](#monitoring--observability)
7. [Disaster Recovery](#disaster-recovery)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

FoodHub Hybrid Cloud Architecture combines **Private Cloud (OpenStack)** and **Public Cloud (AWS)** to deliver:

- ✅ **Cost Optimization**: Run production workloads on OpenStack, scale to AWS during peaks
- ✅ **High Availability**: Multi-cloud redundancy with automatic failover
- ✅ **Data Sovereignty**: Keep sensitive data on-premises (OpenStack)
- ✅ **Cloud Bursting**: Scale to AWS EKS when OpenStack capacity is reached
- ✅ **Disaster Recovery**: Cross-cloud backups and replication

### Key Features

| Feature | OpenStack | AWS | Status |
|---------|-----------|-----|--------|
| Kubernetes | Self-managed | EKS | ✅ Active |
| Container Registry | Harbor | ECR | ✅ Synced |
| Database | PostgreSQL | RDS | ✅ Replicated |
| Networking | VPN Gateway | VPN Gateway | ✅ Connected |
| Monitoring | Prometheus | CloudWatch | ✅ Federated |
| GitOps | ArgoCD Multi-Cluster | ArgoCD Multi-Cluster | ✅ Configured |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        HYBRID CLOUD ARCHITECTURE                        │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────┐       ┌──────────────────────────────┐
│     PRIVATE CLOUD (OpenStack)     │       │     PUBLIC CLOUD (AWS)       │
│                                   │       │                              │
│  ┌─────────────────────────────┐ │       │ ┌──────────────────────────┐ │
│  │  Kubernetes Cluster (1.28)  │ │◄─VPN─►│ │     EKS Cluster          │ │
│  │  - 1 Master, 3 Workers      │ │       │ │  - Managed K8s           │ │
│  │  - Calico CNI               │ │       │ │  - Auto-scaling          │ │
│  └─────────────────────────────┘ │       │ └──────────────────────────┘ │
│                                   │       │                              │
│  ┌─────────────────────────────┐ │       │ ┌──────────────────────────┐ │
│  │  Harbor Registry (v2.10)    │◄├──────►├─┤  ECR (Elastic Registry)  │ │
│  │  - Project: foodhub         │ │ Sync  │ │  - Auto image scanning   │ │
│  │  - Image scanning: Trivy    │ │       │ └──────────────────────────┘ │
│  └─────────────────────────────┘ │       │                              │
│                                   │       │ ┌──────────────────────────┐ │
│  ┌─────────────────────────────┐ │       │ │   RDS PostgreSQL (16.11) │ │
│  │  PostgreSQL 15 (Primary)    │◄├──────►├─┤  - db.t3.micro           │ │
│  │  - foodhub_users            │ │ Repl  │ │  - Read Replica          │ │
│  │  - foodhub_products         │ │       │ │  - Automated backups     │ │
│  │  - foodhub_orders           │ │       │ └──────────────────────────┘ │
│  └─────────────────────────────┘ │       │                              │
│                                   │       │ ┌──────────────────────────┐ │
│  ┌─────────────────────────────┐ │       │ │   VPC (10.1.0.0/16)      │ │
│  │  Network (10.0.0.0/16)      │ │       │ │  - Public Subnets (2)    │ │
│  │  - Private Subnet           │ │       │ │  - Internet Gateway      │ │
│  │  - Router + Floating IPs    │ │       │ │  - Security Groups       │ │
│  └─────────────────────────────┘ │       │ └──────────────────────────┘ │
│                                   │       │                              │
│  ┌─────────────────────────────┐ │       │ ┌──────────────────────────┐ │
│  │  VPN Gateway (strongSwan)   │◄├──────►├─┤  AWS VPN Gateway         │ │
│  │  - IPSec tunnels (2)        │ │ VPN   │ │  - Site-to-Site VPN      │ │
│  │  - 500/UDP, 4500/UDP        │ │       │ │  - BGP routing           │ │
│  └─────────────────────────────┘ │       │ └──────────────────────────┘ │
│                                   │       │                              │
│  ┌─────────────────────────────┐ │       │ ┌──────────────────────────┐ │
│  │  Prometheus + Grafana       │◄├──────►├─┤  CloudWatch              │ │
│  │  - Metrics collection       │ │ Fed   │ │  - EKS metrics           │ │
│  │  - Custom dashboards        │ │       │ │  - RDS monitoring        │ │
│  └─────────────────────────────┘ │       │ └──────────────────────────┘ │
└──────────────────────────────────┘       └──────────────────────────────┘
                    │                                       │
                    └─────────── ArgoCD Multi-Cluster ──────┘
                              GitOps Deployment
```

### Network Topology

```
OpenStack (10.0.0.0/16)  ←→  VPN Tunnel  ←→  AWS VPC (10.1.0.0/16)
     │                            │                      │
     ├─ K8s Master: 10.0.1.10     │         EKS API: eks.amazonaws.com
     ├─ K8s Workers: 10.0.1.11-13 │         Subnets: 10.1.1.0/24
     ├─ PostgreSQL: 10.0.1.20     │                  10.1.2.0/24
     ├─ Harbor: 10.0.1.30         │         RDS: xxxxx.rds.amazonaws.com
     └─ VPN Gateway: 10.0.1.40    │         VPN: vpn-xxxxx.amazonaws.com
```

---

## 📦 Prerequisites

### OpenStack Requirements

- OpenStack cluster (Yoga or newer)
- Available resources:
  - 4 vCPUs + 16GB RAM (Master node)
  - 3 × (4 vCPUs + 16GB RAM) (Worker nodes)
  - 2 × (2 vCPUs + 8GB RAM) (PostgreSQL, Harbor)
  - 1 × (1 vCPU + 2GB RAM) (VPN Gateway)
- External network with floating IP pool
- Ubuntu 22.04 image available
- Terraform 1.0+ installed

### AWS Requirements

- AWS Account with appropriate permissions
- AWS CLI configured
- EKS cluster already deployed (from existing Terraform)
- VPC with CIDR 10.1.0.0/16
- RDS PostgreSQL instance
- ECR repositories

### Tools Required

```bash
# Install required tools
curl -LO https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## 🚀 Deployment Guide

### Step 1: Deploy OpenStack Infrastructure

```bash
cd terraform/openstack

# Set OpenStack credentials
export OS_AUTH_URL="http://your-openstack:5000/v3"
export OS_USERNAME="admin"
export OS_PASSWORD="your-password"
export OS_PROJECT_NAME="foodhub"
export OS_USER_DOMAIN_NAME="Default"
export OS_PROJECT_DOMAIN_NAME="Default"
export OS_REGION_NAME="RegionOne"

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy infrastructure
terraform apply

# Save outputs
terraform output > openstack-outputs.txt
```

**Expected Resources Created:**
- ✅ Private network and subnet
- ✅ Router with external gateway
- ✅ Security groups (K8s, DB, Harbor, VPN)
- ✅ 1 K8s master node
- ✅ 3 K8s worker nodes
- ✅ PostgreSQL database instance
- ✅ Harbor container registry
- ✅ VPN gateway
- ✅ Floating IPs for all instances

### Step 2: Configure Kubernetes Cluster

```bash
# Get master node floating IP
MASTER_IP=$(terraform output -raw k8s_master_floating_ips | jq -r '.[0]')

# SSH to master node
ssh ubuntu@$MASTER_IP

# Check cluster status
kubectl get nodes
kubectl get pods -A

# Get join command for worker nodes
cat /root/kubeadm-join-command.sh

# On each worker node (SSH to worker floating IPs)
# Run the join command from master

# Verify all nodes are ready
kubectl get nodes
```

### Step 3: Setup VPN Connection

```bash
# Get OpenStack VPN Gateway IP
VPN_GATEWAY_IP=$(terraform output -raw vpn_gateway_floating_ip)

# Deploy AWS VPN configuration
cd ../../terraform

# Update variables
echo 'openstack_vpn_gateway_ip = "'$VPN_GATEWAY_IP'"' >> terraform.tfvars

# Apply AWS VPN configuration
terraform apply

# Get AWS VPN configuration
terraform output -raw vpn_tunnel1_address
terraform output -raw vpn_tunnel1_preshared_key

# SSH to OpenStack VPN Gateway
ssh ubuntu@$VPN_GATEWAY_IP

# Copy VPN configuration from terraform output
sudo vi /etc/ipsec.conf
sudo vi /etc/ipsec.secrets

# Start VPN
sudo systemctl restart strongswan
sudo systemctl status strongswan

# Verify VPN tunnel status
sudo ipsec status

# Test connectivity
ping 10.1.1.1  # AWS VPC subnet
```

### Step 4: Configure Harbor Registry

```bash
# Get Harbor IP
HARBOR_IP=$(cd terraform/openstack && terraform output -raw harbor_floating_ip)

# Access Harbor UI
echo "Harbor URL: http://$HARBOR_IP"
echo "Username: admin"
echo "Password: FoodHub@2025"

# Setup Harbor <-> ECR sync
cd ../../scripts/hybrid-cloud
./setup-harbor-ecr-sync.sh $HARBOR_IP admin FoodHub@2025 ap-southeast-1 257394468168

# Verify replication rules
# Open Harbor UI -> Administration -> Replications
```

### Step 5: Configure Database Replication

```bash
# Get database IPs
OPENSTACK_PG_IP=$(cd terraform/openstack && terraform output -raw postgresql_floating_ip)
AWS_RDS_ENDPOINT=$(cd ../../terraform && terraform output -raw rds_endpoint)

# Setup replication
cd scripts/hybrid-cloud
./setup-database-replication.sh $OPENSTACK_PG_IP 5432 $AWS_RDS_ENDPOINT 5432

# Follow the guide in /tmp/aws_rds_replica_guide.md
# to complete AWS DMS configuration
```

### Step 6: Deploy ArgoCD

```bash
# Install ArgoCD on EKS cluster
kubectl config use-context foodhub-eks
./k8s/argocd/install-argocd.sh

# Get ArgoCD password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Login via CLI
argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure

# Register OpenStack Kubernetes cluster
OPENSTACK_K8S_API=$(cd terraform/openstack && terraform output -raw kubernetes_api_endpoint)
kubectl config use-context openstack-k8s
argocd cluster add openstack-k8s --name foodhub-openstack

# Apply multi-cluster configurations
kubectl apply -f k8s/argocd/multi-cluster/

# Deploy ApplicationSet
kubectl apply -f k8s/argocd/multi-cluster/applicationset-hybrid.yaml
```

### Step 7: Configure Jenkins for Hybrid Cloud

```bash
# Add Harbor credentials to Jenkins
# Navigate to: Jenkins -> Manage Jenkins -> Credentials
# Add new credentials:
#   - ID: harbor-credentials
#   - Username: admin
#   - Password: FoodHub@2025

# Add Harbor registry URL
# Add String credential:
#   - ID: harbor-registry-url
#   - Secret: http://HARBOR_IP

# Create new Jenkins pipeline
# Use: CICD/Jenkinsfile.hybrid-cloud
# Set DEPLOYMENT_MODE to 'HYBRID'

# Trigger build
# Jenkins will now build and push to both ECR and Harbor
# And deploy to both EKS and OpenStack K8s via ArgoCD
```

### Step 8: Setup Monitoring

```bash
# Deploy Prometheus federation on EKS
kubectl config use-context foodhub-eks
kubectl create namespace monitoring

# Update Prometheus configuration
kubectl apply -f observability/prometheus-federation.yaml

# Deploy Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana grafana/grafana \
  --namespace monitoring \
  --set adminPassword=FoodHub@2025 \
  --set service.type=LoadBalancer

# Get Grafana URL
kubectl get svc grafana -n monitoring

# Import dashboards
# - Kubernetes Cluster Monitoring
# - PostgreSQL Database
# - Harbor Registry
# - Cross-Cloud Latency
```

---

## ⚙️ Configuration

### Environment Variables

Create `.env` file:

```bash
# OpenStack
export OS_AUTH_URL="http://your-openstack:5000/v3"
export OS_USERNAME="admin"
export OS_PASSWORD="your-password"
export OS_PROJECT_NAME="foodhub"

# AWS
export AWS_REGION="ap-southeast-1"
export AWS_ACCOUNT_ID="257394468168"

# Harbor
export HARBOR_URL="http://harbor-ip"
export HARBOR_USERNAME="admin"
export HARBOR_PASSWORD="FoodHub@2025"

# Database
export OPENSTACK_PG_HOST="10.0.1.20"
export AWS_RDS_HOST="foodhub-rds.xxxxx.ap-southeast-1.rds.amazonaws.com"
```

### Deployment Modes

Jenkins supports 3 deployment modes:

| Mode | Description | Use Case |
|------|-------------|----------|
| `AWS` | Deploy only to AWS EKS | Testing, AWS-only workloads |
| `OPENSTACK` | Deploy only to OpenStack | On-premises only workloads |
| `HYBRID` | Deploy to both clouds | Production, high availability |

Set in Jenkinsfile:
```groovy
environment {
    DEPLOYMENT_MODE = 'HYBRID'
}
```

---

## 📊 Monitoring & Observability

### Metrics Available

**Infrastructure Metrics:**
- CPU, Memory, Disk usage per cloud
- Network throughput and latency
- VPN tunnel status and packet loss

**Application Metrics:**
- Request rate, latency, error rate
- Active connections, queue depth
- Cache hit rate

**Database Metrics:**
- Query performance, slow queries
- Replication lag
- Connection pool usage

**Container Registry:**
- Image pull/push rate
- Replication status
- Vulnerability scan results

### Dashboards

Access Grafana: http://grafana-lb-url

Pre-configured dashboards:
1. **Hybrid Cloud Overview**: Overall system health
2. **Cross-Cloud Comparison**: Side-by-side metrics
3. **Network Performance**: VPN and latency metrics
4. **Database Replication**: Replication lag and status
5. **Application Performance**: Service-specific metrics

### Alerts

Alerts configured in Prometheus:
- VPN tunnel down
- Database replication lag > 5 minutes
- Service unavailable in any cloud
- High cross-cloud latency
- Registry sync failures

---

## 🔄 Disaster Recovery

### Backup Strategy

**Daily Backups:**
- PostgreSQL: pg_basebackup + WAL archiving
- Kubernetes: Velero snapshots
- Harbor: Database and image data

**Cross-Cloud Replication:**
- Database: Continuous replication to AWS RDS
- Container Images: Automatic sync to ECR
- Configuration: GitOps repository

### Failover Procedures

#### OpenStack → AWS Failover

```bash
# 1. Update DNS to point to AWS
# 2. Scale up AWS services
kubectl scale deployment --replicas=5 -n foodhub --all

# 3. Promote RDS to primary
aws rds promote-read-replica --db-instance-identifier foodhub-rds

# 4. Update application config
kubectl set env deployment -n foodhub DB_HOST=new-rds-endpoint
```

#### AWS → OpenStack Failover

```bash
# 1. Update DNS to point to OpenStack
# 2. Scale up OpenStack services
kubectl scale deployment --replicas=5 -n foodhub --all

# 3. Reconfigure database
# Update application to use OpenStack PostgreSQL

# 4. Sync images from ECR to Harbor (if needed)
```

### Recovery Time Objectives (RTO/RPO)

| Scenario | RTO | RPO |
|----------|-----|-----|
| Single cloud failure | 15 minutes | < 5 minutes |
| Database failure | 10 minutes | < 1 minute |
| Complete OpenStack outage | 30 minutes | < 5 minutes |
| Network partition | Auto-healing | 0 (active-active) |

---

## 🔧 Troubleshooting

### VPN Issues

**Problem**: VPN tunnel not establishing

```bash
# Check VPN status
sudo ipsec status
sudo ipsec statusall

# Check logs
sudo journalctl -u strongswan -f

# Restart VPN
sudo ipsec restart

# Test connectivity
ping 10.1.1.1  # AWS side
```

### ArgoCD Sync Issues

**Problem**: Applications out of sync

```bash
# Check application status
argocd app list
argocd app get foodhub-users-aws

# Force sync
argocd app sync foodhub-users-aws

# Check logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### Database Replication Lag

**Problem**: High replication lag

```bash
# Check replication status
psql -h openstack-pg -U postgres -c "SELECT * FROM pg_stat_replication;"

# Check lag
psql -h openstack-pg -U postgres -c "SELECT
  application_name,
  client_addr,
  state,
  pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes
FROM pg_stat_replication;"

# If using AWS DMS
aws dms describe-replication-tasks
aws dms describe-table-statistics --replication-task-arn xxx
```

### Harbor Sync Failures

**Problem**: Images not syncing to ECR

```bash
# Check replication execution
curl -u admin:password http://harbor/api/v2.0/replication/executions

# Retry failed replication
# Via Harbor UI: Administration -> Replications -> Select policy -> Replicate

# Check Harbor logs
docker logs harbor-core
docker logs harbor-jobservice
```

---

## 📚 Additional Resources

- [OpenStack Terraform Provider Docs](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs)
- [AWS VPN Setup Guide](https://docs.aws.amazon.com/vpn/latest/s2svpn/SetUpVPNConnections.html)
- [Harbor Documentation](https://goharbor.io/docs/)
- [ArgoCD Multi-Cluster](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters)
- [PostgreSQL Replication](https://www.postgresql.org/docs/current/high-availability.html)

---

## 🎉 Success Criteria

Your hybrid cloud deployment is successful when:

- [ ] All OpenStack VMs are running and accessible
- [ ] Kubernetes clusters in both clouds are healthy
- [ ] VPN tunnel is established (ping test passes)
- [ ] Harbor <-> ECR sync is working
- [ ] Database replication lag < 5 seconds
- [ ] ArgoCD can deploy to both clusters
- [ ] Jenkins pipeline successfully builds and deploys to both clouds
- [ ] Monitoring shows metrics from both clouds
- [ ] Sample application is accessible from both clouds
- [ ] Failover test completed successfully

---

**Maintained by**: FoodHub DevOps Team
**Last Updated**: 2025-01-12
**Version**: 1.0.0
