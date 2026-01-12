# 🚀 Quick Start: Hybrid Cloud Deployment (OpenStack + AWS)

## ⚡ 5-Minute Setup Guide

### Prerequisites Checklist

```bash
# Check if you have these ready:
□ OpenStack credentials (OS_AUTH_URL, OS_USERNAME, etc.)
□ AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
□ Terraform installed (terraform --version)
□ kubectl installed (kubectl version)
□ 4-6 hours for complete deployment
```

---

## 🎯 Deployment Steps

### 1️⃣ Clone and Setup (2 minutes)

```bash
# Clone repository
git clone https://github.com/NgHVu/DEVSECOPS-HYBRID-CLOUD.git
cd DEVSECOPS-HYBRID-CLOUD

# Set environment variables
cp .env.example .env
nano .env  # Edit with your credentials

# Source environment
source .env
```

### 2️⃣ Deploy OpenStack Infrastructure (30-45 minutes)

```bash
cd terraform/openstack

# Initialize Terraform
terraform init

# Deploy (this will create: VMs, networks, security groups)
terraform apply -auto-approve

# Save outputs
terraform output -json > outputs.json

# Get important IPs
export MASTER_IP=$(terraform output -raw k8s_master_floating_ips | jq -r '.[0]')
export HARBOR_IP=$(terraform output -raw harbor_floating_ip)
export VPN_GATEWAY_IP=$(terraform output -raw vpn_gateway_floating_ip)

echo "Master Node: $MASTER_IP"
echo "Harbor Registry: $HARBOR_IP"
echo "VPN Gateway: $VPN_GATEWAY_IP"
```

**⏳ Wait**: OpenStack VMs are provisioning and configuring (30-45 min)

### 3️⃣ Configure Kubernetes Cluster (10-15 minutes)

```bash
# SSH to master node
ssh ubuntu@$MASTER_IP

# Check cluster status (wait until all nodes are Ready)
watch kubectl get nodes

# Get kubeconfig
sudo cat /root/.kube/config > /tmp/kubeconfig-openstack

# Exit and copy kubeconfig to local machine
exit
scp ubuntu@$MASTER_IP:/tmp/kubeconfig-openstack ~/.kube/config-openstack

# Update kubeconfig with public IP
sed -i "s|https://.*:6443|https://$MASTER_IP:6443|" ~/.kube/config-openstack

# Test connection
kubectl --kubeconfig ~/.kube/config-openstack get nodes
```

### 4️⃣ Setup AWS VPN Connection (15-20 minutes)

```bash
cd ../../terraform

# Update VPN configuration
echo "openstack_vpn_gateway_ip = \"$VPN_GATEWAY_IP\"" >> terraform.tfvars

# Apply AWS VPN
terraform apply -auto-approve

# Get VPN configuration
terraform output > vpn-config.txt

# Configure OpenStack VPN Gateway
ssh ubuntu@$VPN_GATEWAY_IP

# Get the VPN config from terraform output
cat terraform/openstack/configs/aws-vpn-config.conf

# Apply configuration
sudo bash -c 'cat > /etc/ipsec.conf' <<EOF
# Paste VPN configuration here
EOF

sudo bash -c 'cat > /etc/ipsec.secrets' <<EOF
# Paste pre-shared key here
EOF

# Restart VPN
sudo systemctl restart strongswan
sudo ipsec status

# Test connectivity (from OpenStack to AWS)
ping -c 4 10.1.1.1

# Exit back to local machine
exit
```

### 5️⃣ Setup Container Registry Sync (5-10 minutes)

```bash
cd scripts/hybrid-cloud

# Run Harbor-ECR sync setup
./setup-harbor-ecr-sync.sh \
  http://$HARBOR_IP \
  admin \
  FoodHub@2025 \
  ap-southeast-1 \
  257394468168

# Verify in Harbor UI
echo "Open: http://$HARBOR_IP"
echo "Login: admin / FoodHub@2025"
echo "Check: Administration -> Replications"
```

### 6️⃣ Deploy ArgoCD (10 minutes)

```bash
# Install ArgoCD on EKS
kubectl config use-context foodhub-eks
./k8s/argocd/install-argocd.sh

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Get admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD Password: $ARGOCD_PASSWORD"

# Port forward (in background)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Login
argocd login localhost:8080 \
  --username admin \
  --password $ARGOCD_PASSWORD \
  --insecure

# Add OpenStack cluster
kubectl config use-context openstack-k8s
argocd cluster add openstack-k8s --name foodhub-openstack --yes

# Apply multi-cluster config
kubectl config use-context foodhub-eks
kubectl apply -f k8s/argocd/multi-cluster/

# Open ArgoCD UI
echo "Open: http://localhost:8080"
echo "Login: admin / $ARGOCD_PASSWORD"
```

### 7️⃣ Configure Jenkins (5 minutes)

```bash
# Access Jenkins
echo "Jenkins URL: http://jenkins-ip:8080"

# Add credentials:
# 1. Harbor credentials (ID: harbor-credentials)
#    - Username: admin
#    - Password: FoodHub@2025

# 2. Harbor registry URL (ID: harbor-registry-url)
#    - Secret: http://$HARBOR_IP

# 3. Create new pipeline job
#    - Name: foodhub-hybrid-cloud
#    - Pipeline script from SCM
#    - Repository: https://github.com/NgHVu/DEVSECOPS-HYBRID-CLOUD.git
#    - Script path: CICD/Jenkinsfile.hybrid-cloud

# Update Jenkinsfile environment:
# Set DEPLOYMENT_MODE = 'HYBRID'
```

### 8️⃣ Deploy Monitoring (10 minutes)

```bash
# Deploy Prometheus Federation
kubectl config use-context foodhub-eks
kubectl create namespace monitoring

kubectl apply -f observability/prometheus-federation.yaml

# Deploy Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install grafana grafana/grafana \
  --namespace monitoring \
  --set adminPassword=FoodHub@2025 \
  --set service.type=LoadBalancer

# Get Grafana URL
kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

echo "Grafana will be available at the LoadBalancer URL"
echo "Login: admin / FoodHub@2025"
```

### 9️⃣ Test Deployment (5 minutes)

```bash
# Trigger Jenkins build
# This will:
# 1. Build Docker images
# 2. Push to both Harbor and ECR
# 3. Deploy to both OpenStack K8s and AWS EKS via ArgoCD

# Monitor in ArgoCD
# Watch applications sync to both clusters

# Check deployments
kubectl --kubeconfig ~/.kube/config-openstack get pods -n foodhub
kubectl config use-context foodhub-eks && kubectl get pods -n foodhub

# Test services
# Get service IPs from both clusters
kubectl --kubeconfig ~/.kube/config-openstack get svc -n foodhub
kubectl config use-context foodhub-eks && kubectl get svc -n foodhub
```

---

## ✅ Verification Checklist

```bash
# Run these commands to verify your setup:

# 1. Check OpenStack resources
cd terraform/openstack
terraform state list

# 2. Check VPN tunnel
ssh ubuntu@$VPN_GATEWAY_IP "sudo ipsec status"

# 3. Check Kubernetes clusters
kubectl --kubeconfig ~/.kube/config-openstack get nodes
kubectl config use-context foodhub-eks && kubectl get nodes

# 4. Check Harbor
curl -u admin:FoodHub@2025 http://$HARBOR_IP/api/v2.0/health

# 5. Check database connectivity
psql -h $OPENSTACK_PG_IP -U foodhub_user -d foodhub_users -c "SELECT version();"

# 6. Check ArgoCD applications
argocd app list

# 7. Check monitoring
kubectl get pods -n monitoring
```

Expected output:
```
✅ OpenStack: 9+ resources created
✅ VPN: 2 tunnels UP
✅ Kubernetes: All nodes Ready (both clusters)
✅ Harbor: Status 200
✅ Database: PostgreSQL 15.x
✅ ArgoCD: 12 applications Synced
✅ Monitoring: All pods Running
```

---

## 🎯 What's Next?

### Deploy Your First Application

```bash
# 1. Create application in GitOps repo structure
mkdir -p ~/dacn-config/services/myapp/{aws,openstack}

# 2. Create Helm values for each cloud
cat > ~/dacn-config/services/myapp/aws/values.yaml <<EOF
image:
  registry: 257394468168.dkr.ecr.ap-southeast-1.amazonaws.com
  repository: myapp
  tag: latest
EOF

cat > ~/dacn-config/services/myapp/openstack/values.yaml <<EOF
image:
  registry: $HARBOR_IP
  repository: foodhub/myapp
  tag: latest
EOF

# 3. Push to GitOps repo
cd ~/dacn-config
git add .
git commit -m "Add myapp configuration"
git push

# 4. ArgoCD will automatically detect and deploy!
```

### Enable Auto-Scaling

```bash
# AWS EKS - Cluster Autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# OpenStack - Manual scaling for now
# Add more worker nodes via Terraform:
# Update k8s_worker_count in terraform/openstack/variables.tf
```

### Configure Alerts

```bash
# Edit Prometheus alerts
kubectl edit configmap prometheus-hybrid-cloud-rules -n monitoring

# Add Slack webhook
kubectl create secret generic alertmanager-slack-webhook \
  --from-literal=url=https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -n monitoring
```

---

## 🆘 Quick Troubleshooting

### VPN not working?
```bash
# Check AWS side
aws ec2 describe-vpn-connections

# Check OpenStack side
ssh ubuntu@$VPN_GATEWAY_IP "sudo ipsec statusall"

# Restart VPN
ssh ubuntu@$VPN_GATEWAY_IP "sudo systemctl restart strongswan"
```

### Can't access Kubernetes?
```bash
# Check if nodes are ready
kubectl get nodes

# Check if API server is accessible
kubectl cluster-info

# Re-fetch kubeconfig
scp ubuntu@$MASTER_IP:/root/.kube/config ~/.kube/config-openstack
```

### ArgoCD not syncing?
```bash
# Check application status
argocd app get myapp-aws --show-params

# Force sync
argocd app sync myapp-aws --force

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller -f
```

---

## 📞 Support

- 📖 Full Documentation: [docs/hybrid-cloud/README.md](README.md)
- 🐛 Issues: https://github.com/NgHVu/DEVSECOPS-HYBRID-CLOUD/issues
- 💬 Discussions: https://github.com/NgHVu/DEVSECOPS-HYBRID-CLOUD/discussions

---

**Total Setup Time**: ~2-3 hours (automated) + validation

**Ready for Production?** Review the full [Deployment Guide](README.md) for production best practices!
