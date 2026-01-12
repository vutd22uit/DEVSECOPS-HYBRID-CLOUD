# 🎬 KỊCH BẢN DEMO TEST HYBRID CLOUD

> **Mục đích**: Chứng minh hệ thống Hybrid Cloud hoạt động đúng cách giữa AWS và OpenStack.

---

## 📋 TỔNG QUAN KỊCH BẢN

| Bước | Tên Demo | Mục tiêu kiểm tra | Thời gian |
|------|----------|-------------------|-----------|
| 1 | Health Check | Kiểm tra kết nối cả 2 cloud | 1 phút |
| 2 | Deploy Sync | ArgoCD đồng bộ cả 2 môi trường | 2 phút |
| 3 | Cross-Cloud API | Gọi API từ cloud này sang cloud kia | 2 phút |
| 4 | Failover Test | Tắt OpenStack → AWS vẫn chạy | 3 phút |
| 5 | Registry Sync | Image replicate từ Harbor → ECR | 2 phút |

**Tổng thời gian**: ~10 phút

---

## 🔧 CHUẨN BỊ TRƯỚC DEMO

### Terminal Setup
```bash
# Terminal 1: kubectl cho AWS
export KUBECONFIG=~/.kube/aws-config
alias k-aws="kubectl --context=aws-eks"

# Terminal 2: kubectl cho OpenStack
export KUBECONFIG=~/.kube/openstack-config
alias k-os="kubectl --context=openstack-k8s"

# Terminal 3: Monitoring
watch -n2 "k-aws get pods -n foodhub && echo '---' && k-os get pods -n foodhub"
```

### Browser Tabs
1. **Tab 1**: ArgoCD UI (`https://argocd.example.com`)
2. **Tab 2**: Grafana Dashboard (`https://grafana.example.com`)
3. **Tab 3**: Frontend App AWS (`https://app.aws.example.com`)
4. **Tab 4**: Frontend App OpenStack (`https://app.openstack.example.com`)

---

## 🧪 BƯỚC 1: HEALTH CHECK (1 phút)

### Mục tiêu
Xác nhận cả 2 clusters đang hoạt động và pods healthy.

### Lệnh thực hiện

```bash
# Kiểm tra AWS EKS
echo "=== AWS EKS Cluster ==="
k-aws get nodes
k-aws get pods -n foodhub -o wide

# Kiểm tra OpenStack K8s
echo "=== OpenStack K8s Cluster ==="
k-os get nodes
k-os get pods -n foodhub -o wide

# Health API Check
echo "=== Health Endpoints ==="
curl -s https://api.aws.example.com/health | jq
curl -s https://api.openstack.example.com/health | jq
```

### Kết quả mong đợi
```json
// AWS Response
{"status": "UP", "cloud": "aws", "cluster": "foodhub-eks", "region": "ap-southeast-1"}

// OpenStack Response
{"status": "UP", "cloud": "openstack", "cluster": "foodhub-k8s", "region": "RegionOne"}
```

### ✅ Pass Criteria
- Tất cả nodes: `Ready`
- Tất cả pods: `Running`
- API trả về `status: UP`

---

## 🔄 BƯỚC 2: DEPLOY SYNC TEST (2 phút)

### Mục tiêu
Thay đổi config và xem ArgoCD đồng bộ lên cả 2 clouds.

### Lệnh thực hiện

```bash
# Bước 2.1: Sửa ConfigMap (thêm timestamp)
TIMESTAMP=$(date +%s)
cat > /tmp/configmap-patch.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: foodhub-config
  namespace: foodhub
data:
  demo-timestamp: "${TIMESTAMP}"
  demo-message: "Hybrid Cloud Test - $(date)"
EOF

# Bước 2.2: Apply qua GitOps (commit to repo)
cd gitops-repo
cp /tmp/configmap-patch.yaml overlays/base/
git add . && git commit -m "Demo: Update timestamp ${TIMESTAMP}"
git push origin main

# Bước 2.3: Theo dõi ArgoCD sync
argocd app sync foodhub-aws
argocd app sync foodhub-openstack

# Bước 2.4: Verify trên cả 2 clusters
echo "=== AWS ConfigMap ==="
k-aws get configmap foodhub-config -n foodhub -o yaml | grep demo-

echo "=== OpenStack ConfigMap ==="
k-os get configmap foodhub-config -n foodhub -o yaml | grep demo-
```

### ✅ Pass Criteria
- ArgoCD hiển thị: `Synced` và `Healthy`
- ConfigMap có cùng `demo-timestamp` trên cả 2 clouds

---

## 🌐 BƯỚC 3: CROSS-CLOUD API TEST (2 phút)

### Mục tiêu
Chứng minh services có thể giao tiếp qua VPN tunnel giữa 2 clouds.

### Lệnh thực hiện

```bash
# Test 1: Từ pod AWS gọi API OpenStack
k-aws exec -it deploy/foodhub-frontend -n foodhub -- \
  curl -s http://10.0.1.100:8082/api/users/health

# Test 2: Từ pod OpenStack gọi API AWS
k-os exec -it deploy/foodhub-frontend -n foodhub -- \
  curl -s http://10.1.1.100:8082/api/users/health

# Test 3: VPN Tunnel Status
k-aws exec -it deploy/vpn-gateway -n kube-system -- ipsec status

# Test 4: Ping across clouds
k-aws exec -it deploy/foodhub-users -n foodhub -- ping -c 3 10.0.1.100
```

### ✅ Pass Criteria
- API calls trả về HTTP 200
- VPN tunnel: `ESTABLISHED`
- Ping latency < 50ms

---

## 💥 BƯỚC 4: FAILOVER TEST (3 phút)

### Mục tiêu
Mô phỏng sự cố OpenStack và chứng minh AWS vẫn hoạt động.

### Kịch bản

```bash
# Bước 4.1: Ghi nhận trạng thái ban đầu
echo "=== BEFORE FAILOVER ==="
k-aws get pods -n foodhub | grep Running | wc -l
k-os get pods -n foodhub | grep Running | wc -l

# Bước 4.2: Mô phỏng lỗi - Scale down OpenStack
k-os scale deployment --all -n foodhub --replicas=0

# Bước 4.3: Kiểm tra Frontend vẫn accessible
echo "=== Testing AWS Frontend ==="
curl -s -o /dev/null -w "%{http_code}" https://app.aws.example.com
# Mong đợi: 200

echo "=== Testing OpenStack Frontend ==="
curl -s -o /dev/null -w "%{http_code}" https://app.openstack.example.com
# Mong đợi: 503 hoặc timeout

# Bước 4.4: Khôi phục OpenStack
k-os scale deployment foodhub-users -n foodhub --replicas=2
k-os scale deployment foodhub-products -n foodhub --replicas=2
k-os scale deployment foodhub-orders -n foodhub --replicas=2
k-os scale deployment foodhub-frontend -n foodhub --replicas=2

# Bước 4.5: Chờ recovery và verify
sleep 30
k-os get pods -n foodhub
```

### ✅ Pass Criteria
- AWS Frontend: HTTP 200 suốt quá trình
- OpenStack phục hồi trong < 60 giây
- Không mất data

---

## 📦 BƯỚC 5: REGISTRY SYNC TEST (2 phút)

### Mục tiêu
Chứng minh images được đồng bộ từ Harbor (OpenStack) sang ECR (AWS).

### Lệnh thực hiện

```bash
# Bước 5.1: Push image mới lên Harbor
docker tag myapp:test harbor.openstack.local/foodhub/demo-test:v1
docker push harbor.openstack.local/foodhub/demo-test:v1

# Bước 5.2: Chờ replication (thường < 30 giây)
sleep 30

# Bước 5.3: Verify image có trên ECR
aws ecr describe-images \
  --repository-name foodhub/demo-test \
  --region ap-southeast-1 \
  --query 'imageDetails[*].imageTags'

# Bước 5.4: Kiểm tra Harbor replication logs
curl -u admin:Harbor12345 \
  "https://harbor.openstack.local/api/v2.0/replication/executions?policy_id=1" | jq
```

### ✅ Pass Criteria
- Image xuất hiện trên ECR
- Replication status: `Succeed`
- Image digest khớp nhau

---

## 📊 BẢNG TỔNG KẾT KẾT QUẢ

| Test Case | AWS | OpenStack | VPN | Status |
|-----------|-----|-----------|-----|--------|
| Cluster Health | ⬜ | ⬜ | - | - |
| Pod Running | ⬜ | ⬜ | - | - |
| API Health | ⬜ | ⬜ | - | - |
| ArgoCD Sync | ⬜ | ⬜ | - | - |
| Cross-Cloud Call | ⬜ | ⬜ | ⬜ | - |
| Failover | ⬜ | ⬜ | - | - |
| Registry Sync | ⬜ | ⬜ | - | - |

**Ghi chú**: ⬜ = Chưa test, ✅ = Pass, ❌ = Fail

---

## 🎥 GHI HÌNH DEMO (Khuyến nghị)

```bash
# Sử dụng asciinema để record terminal
asciinema rec hybrid-cloud-demo.cast

# Hoặc dùng script command
script -q hybrid-cloud-demo.log
```

---

## 🆘 TROUBLESHOOTING NHANH

| Vấn đề | Nguyên nhân | Giải pháp |
|--------|-------------|-----------|
| VPN không kết nối | IPSec config sai | `ipsec restart` |
| ArgoCD không sync | Git credentials hết hạn | Refresh token |
| Pod CrashLoop | Image pull failed | Check registry auth |
| Cross-cloud timeout | Security group block | Mở port tương ứng |

---

**📅 Cập nhật lần cuối**: 2026-01-13

**👤 Tác giả**: Vu Truong Doan
