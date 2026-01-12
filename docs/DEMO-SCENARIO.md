# 🎭 Kịch Bản Demo: DevSecOps Hybrid Cloud (No Terraform)

> **Mục tiêu**: Chứng minh khả năng triển khai, bảo mật và vận hành hệ thống microservices trên môi trường Hybrid Cloud hoàn toàn bằng scripts thủ công.

---

## 🎬 Tổng Quan Kịch Bản Demo (5 Phút "Wow")

| Bước | Hoạt Động | Điểm Nhấn (Wow Factor) | Thời Lượng |
|------|-----------|-------------------------|------------|
| **1. Infra Prep** | Chạy scripts tạo Cloud Infra | "Tạo cả cụm EKS/RDS chỉ bằng 1 dòng lệnh CLI" | 30s |
| **2. CI/CD Run** | Push code → Jenkins Pipeline | "Auto scanning (Trivy + SonarQube) & Multi-registry push" | 1m |
| **3. GitOps Sync** | ArgoCD tự động deploy | "Self-healing & Auto-sync giữa AWS và OpenStack" | 1m |
| **4. Hybrid Monitoring**| Grafana Dashboard | "Federated metrics: Xem status cả 2 cloud trên 1 màn hình" | 1m |
| **5. High Availability**| Giết pod/node trên OpenStack | "Hệ thống tự phục hồi hoặc failover sang AWS" | 1m |
| **6. Security Check** | Xem report Trivy/SonarQube | "Security-gate: Code bẩn/vuln không thể deploy" | 30s |

---

## 🛠️ Chuẩn Bị Trước Demo

1. **Terminal 1**: SSH sẵn vào K8s Master (OpenStack).
2. **Terminal 2**: Cấu hình sẵn AWS CLI.
3. **Browser Tab 1**: Jenkins (`localhost:8080`).
4. **Browser Tab 2**: SonarQube (`localhost:9000`).
5. **Browser Tab 3**: ArgoCD UI.
6. **Browser Tab 4**: Grafana UI.
7. **Browser Tab 5**: App Frontend.

---

## 📝 Chi Tiết Từng Bước

### Bước 1: Trình Diễn "IaC Manual" (Infra Setup)
Show cho người xem các scripts trong `manual-deployment/`.
- **Hành động**: Chạy một phần script tạo ECR hoặc RDS.
- **Lời thoại**: "Thay vì Terraform, chúng tôi sử dụng mô hình CLI-First. Scripts của chúng tôi đảm bảo tính idempotent và bảo mật tối đa."

### Bước 2: DevSecOps Flow (The "Push")
Thay đổi một dòng code nhỏ trong `services/users` (ví dụ: đổi message API).
- **Hành động**: `git commit -m "Update API for demo" && git push`
- **Show**: Jenkins Pipeline bắt đầu chạy. Nhấn mạnh vào:
  - **Trivy**: Quét lỗ hổng image.
  - **SonarQube**: Phân tích chất lượng code (Gate: code phải pass mới được deploy).
  - **Registry Push**: Image được đẩy song song lên GHCR, ECR và Harbor.

### Bước 3: Hybrid Deployment (The "Sync")
Mở ArgoCD.
- **Show**: ArgoCD nhận diện thay đổi image tag từ GitOps repo.
- **Hành động**: Bấm Sync (nếu không để auto).
- **Show**: Pods mới được tạo trên cả AWS EKS và OpenStack K8s.
- **Lời thoại**: "ArgoCD quản lý trạng thái mong muốn của hệ thống trên cả Public và Private Cloud, đảm bảo tính nhất quán."

### Bước 4: Observability (The "Eyes")
Mở Grafana.
- **Show**: Dashboard "FoodHub Hybrid Overview".
- **Wow**: Chỉ ra metrics đang đổ về từ cả AWS (ap-southeast-1) và OpenStack (RegionOne).
- **Show**: Sự khác biệt về CPU/RAM giữa các môi trường.

### Bước 5: Phục Hồi & Tự Động Hóa (The "Resilience")
- **Hành động**: Manual delete pod của `foodhub-users` trên OpenStack.
- **Show**: Kubernetes tự động tạo pod mới trong vài giây.
- **Hành động (Khó hơn)**: Shut down 1 worker node trên OpenStack.
- **Show**: Load balancer hướng traffic sang các pods còn lại hoặc sang AWS (nếu có Global LB).

### Bước 6: Kết Thúc (The "Value")
Mở Frontend App.
- **Show**: App chạy mượt mà, gọi API thành công từ cả 2 cloud.
- **Kết luận**: "Chúng tôi đã xây dựng một hệ thống Hybrid Cloud hoàn chỉnh, bảo mật và tự động hóa mà không cần tốn chi phí cho các công cụ IaC phức tạp."

---

## 💡 Mẹo Để Demo Thành Công

1. **Sử dụng nip.io**: Để demo URLs như `argocd.10.0.1.x.nip.io` trông rất chuyên nghiệp.
2. **Cheat Sheet**: Lưu sẵn các lệnh `kubectl get pods` hay để alias cho nhanh.
3. **Recording**: Luôn có 1 video quay sẵn (Backup) phòng trường hợp mạng/Cloud die.
4. **Clean State**: Chạy `./manual-deployment/cleanup.sh` (nếu có) trước khi bắt đầu demo thật.

---

## ✅ Checklist Hoàn Thành Demo

- [ ] Jenkins Credentials đã nạp đủ.
- [ ] AWS Quota còn đủ cho Cluster mới.
- [ ] OpenStack Network đã thông (Ping được 8.8.8.8).
- [ ] SSH Keys đã được add vào Agent.
- [ ] VPN Hub đã ESTABLISHED.
