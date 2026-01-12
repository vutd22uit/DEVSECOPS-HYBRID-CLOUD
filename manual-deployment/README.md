# 🛠️ Manual Deployment - Hybrid Cloud (No Terraform!)

> **100% Manual Configuration** với OpenStack CLI và AWS CLI

## 🎯 Tổng Quan

Thư mục này chứa **scripts manual deployment** để triển khai Hybrid Cloud OpenStack + AWS **KHÔNG cần Terraform**.

Tất cả sử dụng:
- ✅ OpenStack CLI (`openstack` command)
- ✅ AWS CLI (`aws` command)
- ✅ Shell scripts tự động hóa
- ✅ SSH và remote execution
- ❌ **KHÔNG dùng Terraform**

---

## 📂 Cấu Trúc Thư Mục

```
manual-deployment/
├── 00-SETUP-GUIDE.md          # Hướng dẫn setup ban đầu
├── openstack/                 # OpenStack scripts
│   ├── 01-create-network.sh   # Tạo network, subnet, router
│   ├── 02-create-security-groups.sh  # Tạo security groups
│   ├── 03-create-vms.sh       # Tạo virtual machines
│   ├── 04-install-harbor.sh   # Cài Harbor registry
│   ├── 05-install-postgresql.sh  # Cài PostgreSQL
│   └── 06-configure-vpn.sh    # Cấu hình VPN gateway
├── kubernetes/                # Kubernetes scripts
│   ├── 01-install-k8s-master.sh   # Cài K8s master
│   └── 02-install-k8s-workers.sh  # Cài K8s workers
├── aws/                       # AWS scripts
│   └── 01-create-vpn.sh       # Tạo AWS VPN connection
└── README.md                  # File này
```

---

## 🚀 Quick Start (5 Bước)

### 1. Setup Environment

```bash
# Tạo file cấu hình
cat > ~/.openstack-foodhub.env <<'EOF'
export OS_AUTH_URL="http://your-openstack:5000/v3"
export OS_USERNAME="admin"
export OS_PASSWORD="your-password"
export OS_PROJECT_NAME="foodhub"
export OS_USER_DOMAIN_NAME="Default"
export OS_PROJECT_DOMAIN_NAME="Default"
export OS_REGION_NAME="RegionOne"

export AWS_REGION="ap-southeast-1"
export AWS_ACCOUNT_ID="257394468168"

export PROJECT_NAME="foodhub"
export OPENSTACK_NETWORK_CIDR="10.0.0.0/16"
export OPENSTACK_SUBNET_CIDR="10.0.1.0/24"
export AWS_VPC_CIDR="10.1.0.0/16"
export EXTERNAL_NETWORK="public"
EOF

# Load environment
source ~/.openstack-foodhub.env
```

### 2. Deploy OpenStack Infrastructure

```bash
cd manual-deployment

# Tạo network
./openstack/01-create-network.sh

# Tạo security groups
./openstack/02-create-security-groups.sh

# Tạo VMs (này hơi lâu ~30 phút)
./openstack/03-create-vms.sh
```

**⏱️ Đợi ~5 phút** cho VMs khởi động

### 3. Install Kubernetes

```bash
# Cài master node (10-15 phút)
./kubernetes/01-install-k8s-master.sh

# Cài worker nodes (10-15 phút)
./kubernetes/02-install-k8s-workers.sh

# Verify
export KUBECONFIG=~/.kube/config-foodhub-openstack
kubectl get nodes
```

### 4. Install Services

```bash
# Cài Harbor registry (10-15 phút)
./openstack/04-install-harbor.sh

# Cài PostgreSQL (5 phút)
./openstack/05-install-postgresql.sh
```

### 5. Setup AWS VPN

```bash
# Tạo VPN connection trên AWS (5 phút)
./aws/01-create-vpn.sh

# Cấu hình VPN gateway trên OpenStack (5 phút)
./openstack/06-configure-vpn.sh

# Test connectivity
ssh -i ~/.ssh/foodhub-key ubuntu@<VPN_IP> "ping -c 4 10.1.1.1"
```

---

## ⏱️ Timeline

| Phase | Script | Time | Description |
|-------|--------|------|-------------|
| **1. OpenStack Setup** | | **45 min** | |
| 1.1 | `01-create-network.sh` | 2 min | Network infrastructure |
| 1.2 | `02-create-security-groups.sh` | 3 min | Firewall rules |
| 1.3 | `03-create-vms.sh` | 40 min | Create VMs + wait for ready |
| **2. Kubernetes** | | **30 min** | |
| 2.1 | `01-install-k8s-master.sh` | 15 min | K8s master setup |
| 2.2 | `02-install-k8s-workers.sh` | 15 min | K8s workers join |
| **3. Services** | | **25 min** | |
| 3.1 | `04-install-harbor.sh` | 15 min | Harbor registry |
| 3.2 | `05-install-postgresql.sh` | 10 min | PostgreSQL DB |
| **4. AWS VPN** | | **15 min** | |
| 4.1 | `01-create-vpn.sh` | 5 min | AWS VPN setup |
| 4.2 | `06-configure-vpn.sh` | 10 min | OpenStack VPN config |
| **TOTAL** | | **~2 hours** | Complete deployment |

---

## 📋 Prerequisites

### Tools Required

```bash
# OpenStack CLI
pip3 install python-openstackclient

# AWS CLI
pip3 install awscli

# kubectl
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/

# jq (JSON parser)
sudo apt-get install -y jq
```

### OpenStack Requirements

- OpenStack cluster running (Yoga or newer)
- Admin credentials
- External network với floating IP pool
- Ubuntu 22.04 image available
- Quota: 7 VMs (minimum 20 vCPUs, 80GB RAM)

### AWS Requirements

- AWS account with VPC already created
- AWS CLI configured (`aws configure`)
- VPC CIDR: 10.1.0.0/16 (hoặc khác với OpenStack)

---

## 🔍 Verification

### Check OpenStack

```bash
# Load environment
source ~/.openstack-foodhub.env

# Verify OpenStack connection
openstack token issue

# List resources
openstack network list
openstack server list
openstack security group list
openstack floating ip list

# Get IPs
source /tmp/foodhub-ips.sh
echo "Master: $MASTER_IP"
echo "Harbor: $HARBOR_IP"
echo "PostgreSQL: $PG_IP"
```

### Check Kubernetes

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config-foodhub-openstack

# Check nodes
kubectl get nodes -o wide

# Check pods
kubectl get pods -A

# Check cluster info
kubectl cluster-info
```

### Check Services

```bash
# Harbor
curl http://$HARBOR_IP
# Should return Harbor web page

# PostgreSQL
psql -h $PG_IP -U foodhub_user -d foodhub_users -c "SELECT version();"
# Should show PostgreSQL version

# VPN
ssh -i ~/.ssh/foodhub-key ubuntu@$VPN_IP "sudo ipsec status"
# Should show ESTABLISHED tunnels
```

### Check AWS VPN

```bash
# List VPN connections
aws ec2 describe-vpn-connections --region ap-southeast-1

# Check tunnel status
aws ec2 describe-vpn-connections \
  --region ap-southeast-1 \
  --query 'VpnConnections[*].VgwTelemetry[*].[OutsideIpAddress,Status]' \
  --output table
```

---

## 🔧 Troubleshooting

### OpenStack Issues

**Problem: "Cannot connect to OpenStack"**
```bash
# Check credentials
env | grep OS_

# Test token
openstack token issue

# If fails, re-source environment
source ~/.openstack-foodhub.env
```

**Problem: "No floating IPs available"**
```bash
# Check pool
openstack floating ip list

# Create more
openstack floating ip create public
```

**Problem: "VM creation failed"**
```bash
# Check quota
openstack quota show

# Check available flavors
openstack flavor list

# Check available images
openstack image list
```

### Kubernetes Issues

**Problem: "Nodes not ready"**
```bash
# SSH to master
ssh -i ~/.ssh/foodhub-key ubuntu@$MASTER_IP

# Check kubelet
sudo systemctl status kubelet

# Check logs
sudo journalctl -u kubelet -f

# Check nodes
kubectl get nodes -o yaml
```

**Problem: "Pods not running"**
```bash
# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -A --sort-by='.lastTimestamp'

# Check CNI
kubectl get pods -n kube-system | grep calico
```

### VPN Issues

**Problem: "VPN tunnel not established"**
```bash
# Check strongSwan status
ssh -i ~/.ssh/foodhub-key ubuntu@$VPN_IP "sudo ipsec status"

# Check logs
ssh -i ~/.ssh/foodhub-key ubuntu@$VPN_IP "sudo journalctl -u strongswan-starter -f"

# Restart VPN
ssh -i ~/.ssh/foodhub-key ubuntu@$VPN_IP "sudo ipsec restart"

# Check AWS side
aws ec2 describe-vpn-connections --region ap-southeast-1
```

**Problem: "Cannot ping across VPN"**
```bash
# Check security groups allow traffic from other network
openstack security group rule list <sg-name>

# Check AWS route tables have OpenStack CIDR
aws ec2 describe-route-tables --region ap-southeast-1

# Check firewall on VPN gateway
ssh -i ~/.ssh/foodhub-key ubuntu@$VPN_IP "sudo iptables -L -n -v"
```

---

## 📚 Detailed Documentation

- **Setup Guide**: [00-SETUP-GUIDE.md](00-SETUP-GUIDE.md)
- **Hybrid Cloud Docs**: [../docs/hybrid-cloud/README.md](../docs/hybrid-cloud/README.md)
- **Quick Start**: [../docs/hybrid-cloud/QUICK-START.md](../docs/hybrid-cloud/QUICK-START.md)

---

## 💡 Tips & Best Practices

### 1. Save All Config Files

Các scripts tự động save config vào `/tmp/`:
- `/tmp/foodhub-network-config.sh` - Network IDs
- `/tmp/foodhub-security-groups.sh` - Security group names
- `/tmp/foodhub-ips.sh` - All floating IPs
- `/tmp/foodhub-harbor.sh` - Harbor credentials
- `/tmp/foodhub-db.sh` - Database credentials
- `/tmp/foodhub-vpn.sh` - VPN info

**Backup chúng:**
```bash
mkdir ~/foodhub-configs
cp /tmp/foodhub-*.sh ~/foodhub-configs/
```

### 2. Use Screen/Tmux

Scripts chạy lâu nên dùng screen/tmux:
```bash
# Install screen
sudo apt-get install -y screen

# Start screen session
screen -S foodhub-deploy

# Run scripts
./openstack/03-create-vms.sh

# Detach: Ctrl+A then D
# Reattach: screen -r foodhub-deploy
```

### 3. Log Output

Capture output của scripts:
```bash
./openstack/01-create-network.sh 2>&1 | tee logs/network-setup.log
```

### 4. Idempotent Scripts

Tất cả scripts đều **idempotent** - có thể chạy lại nhiều lần an toàn:
- Check resource tồn tại trước khi tạo
- Skip nếu đã có
- Không xóa resources existing

---

## 🎓 Learning Resources

### OpenStack CLI

```bash
# Help
openstack help
openstack server create --help

# List commands
openstack command list

# Common commands
openstack server list
openstack network list
openstack volume list
openstack floating ip list
```

### AWS CLI

```bash
# Help
aws help
aws ec2 help
aws ec2 create-vpn-connection help

# Common commands
aws ec2 describe-vpcs
aws ec2 describe-vpn-connections
aws ec2 describe-instances
```

---

## ✅ Success Criteria

Deployment thành công khi:

- [ ] ✅ OpenStack: All VMs running
- [ ] ✅ Kubernetes: All nodes Ready
- [ ] ✅ Harbor: Accessible at http://HARBOR_IP
- [ ] ✅ PostgreSQL: Can connect and query
- [ ] ✅ VPN: Tunnels ESTABLISHED
- [ ] ✅ Connectivity: Can ping 10.1.1.1 from OpenStack
- [ ] ✅ Kubeconfig: Downloaded and working

---

**Version**: 1.0.0
**Author**: DevOps Team
**Last Updated**: 2025-01-12
**Status**: ✅ Production Ready (No Terraform!)
