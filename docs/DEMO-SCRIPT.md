# 🎭 KỊCH BẢN DEMO CHI TIẾT
## DevSecOps Hybrid Cloud CI/CD Pipeline

> **Thời lượng dự kiến**: 15-20 phút  
> **Đối tượng**: Giảng viên, Hội đồng báo cáo, Doanh nghiệp

---

## 📋 TỔNG QUAN DỰ ÁN

### Mục tiêu Demo
Chứng minh khả năng xây dựng và vận hành một hệ thống **DevSecOps Hybrid Cloud** hoàn chỉnh, bao gồm:
- CI/CD Pipeline tự động với tích hợp bảo mật
- Triển khai song song trên AWS (Public Cloud) và OpenStack (Private Cloud)
- Giám sát tập trung và khả năng tự phục hồi

### Công nghệ sử dụng
| Thành phần | Công nghệ |
|------------|-----------|
| Cloud | AWS EKS + OpenStack Kubernetes |
| CI/CD | Jenkins + ArgoCD |
| Security | Trivy + SonarQube |
| Monitoring | Prometheus + Grafana |
| Registry | GHCR + AWS ECR + Harbor |

---

## 🎬 PHẦN 1: GIỚI THIỆU (3 phút)

### 1.1 Mở đầu
**[Slide: Trang bìa dự án]**

> **Lời thoại:**  
> "Kính chào Thầy/Cô và các bạn. Hôm nay em xin trình bày đề tài **'Xây dựng hệ thống DevSecOps CI/CD Pipeline cho môi trường Hybrid Cloud'**.
>
> Trong bối cảnh doanh nghiệp hiện đại, việc kết hợp giữa **Private Cloud** cho dữ liệu nhạy cảm và **Public Cloud** cho khả năng mở rộng đã trở thành xu hướng tất yếu. Tuy nhiên, quản lý bảo mật và triển khai đồng bộ trên nhiều cloud là thách thức lớn.
>
> Dự án này giải quyết thách thức đó bằng cách xây dựng một **pipeline CI/CD tự động**, tích hợp **Shift-Left Security** ngay từ giai đoạn phát triển."

### 1.2 Kiến trúc hệ thống
**[Show: Sơ đồ kiến trúc]**

> **Lời thoại:**  
> "Đây là kiến trúc tổng quan của hệ thống:
> - **Tầng CI/CD**: Jenkins làm brain orchestration, kết hợp SonarQube và Trivy cho security scanning
> - **Tầng Connectivity**: VPN Site-to-Site kết nối 2 cloud với độ bảo mật cao
> - **Tầng Deployment**: ArgoCD (GitOps) tự động sync trạng thái mong muốn lên cả 2 cụm Kubernetes"

---

## 🔧 PHẦN 2: DEMO LOCAL ENVIRONMENT (3 phút)

### 2.1 Khởi động môi trường
**[Terminal]**

```bash
# Mở thư mục project
cd DEVSECOPS-HYBRID-CLOUD

# Khởi động demo
./demo.sh
```

> **Lời thoại:**  
> "Đầu tiên, em sẽ khởi động môi trường local để simulate toàn bộ hệ thống. Chỉ với một lệnh duy nhất, Docker Compose sẽ khởi động:
> - **3 microservices** backend (Users, Products, Orders)
> - **1 Frontend** Next.js
> - **Jenkins** CI server
> - **SonarQube** code analysis"

### 2.2 Trình bày Frontend
**[Browser: http://localhost:3000]**

> **Lời thoại:**  
> "Đây là ứng dụng **FoodHub** - một hệ thống quản lý đơn hàng thực phẩm. Chú ý thanh trạng thái ở góc trên phải hiển thị thông tin **Cloud Provider** và **Cluster** đang active.
>
> Khi triển khai lên Production, thanh này sẽ tự động cập nhật để cho biết user đang được serve từ AWS hay OpenStack."

---

## 🔐 PHẦN 3: SECURITY PIPELINE (5 phút)

### 3.1 Jenkins Pipeline Overview
**[Browser: http://localhost:8080 - Login: admin/admin123]**

> **Lời thoại:**  
> "Jenkins là trung tâm điều khiển của hệ thống CI/CD. Em sẽ mở pipeline **FoodHub-Hybrid-Pipeline** để xem các stage."

**[Show: Jenkinsfile stages]**

> **Lời thoại:**  
> "Pipeline của em có 8 stages chính:
> 1. **Checkout** - Clone source code
> 2. **Build & Test** - Compile và chạy unit tests
> 3. **SonarQube Analysis** - Phân tích chất lượng code
> 4. **Docker Build** - Build container image
> 5. **Trivy Scan** - Quét lỗ hổng bảo mật
> 6. **Push to Registry** - Đẩy image lên 3 registry cùng lúc
> 7. **Update GitOps** - Cập nhật manifest cho ArgoCD
> 8. **Deploy & Verify** - Triển khai và kiểm tra health"

### 3.2 Trigger Pipeline với Code Change
**[Terminal]**

```bash
# Thay đổi 1 dòng code
vim services/users/src/main/java/com/foodhub/users/controller/UserController.java

# Commit và push
git add . && git commit -m "Demo: Update API message" && git push
```

> **Lời thoại:**  
> "Bây giờ em sẽ thực hiện một thay đổi nhỏ trong code. Ngay khi push lên GitHub, webhook sẽ trigger Jenkins pipeline."

**[Show: Jenkins build running]**

> **Lời thoại:**  
> "Pipeline đã được trigger tự động. Các bạn có thể thấy các stage đang chạy theo thứ tự..."

### 3.3 SonarQube Analysis
**[Browser: http://localhost:9000]**

> **Lời thoại:**  
> "Đây là **SonarQube Dashboard**. Nó phân tích:
> - **Code Smells**: Các vấn đề về maintainability
> - **Bugs**: Lỗi tiềm ẩn trong logic
> - **Vulnerabilities**: Lỗ hổng bảo mật trong code
> - **Coverage**: Độ phủ của unit tests
>
> Nếu code không pass **Quality Gate**, pipeline sẽ tự động FAIL và không cho phép deploy."

### 3.4 Trivy Security Scan
**[Show: Jenkins console log cho Trivy stage]**

> **Lời thoại:**  
> "**Trivy** quét container image để phát hiện:
> - CVE (Common Vulnerabilities and Exposures)
> - Thư viện cũ có lỗ hổng
> - Misconfiguration trong Dockerfile
>
> Nếu tìm thấy lỗ hổng mức **HIGH** hoặc **CRITICAL**, pipeline sẽ dừng lại ngay. Đây chính là **Shift-Left Security** - phát hiện lỗi sớm nhất có thể."

---

## ☁️ PHẦN 4: HYBRID DEPLOYMENT (5 phút)

### 4.1 Multi-Registry Push
**[Show: Jenkins console log]**

> **Lời thoại:**  
> "Sau khi pass tất cả security gates, Docker image được push **song song** tới 3 registry:
> 1. **GHCR** (GitHub Container Registry) - Public registry chính
> 2. **AWS ECR** - Cho EKS cluster
> 3. **Harbor** - Private registry cho OpenStack
>
> Việc này đảm bảo cả 2 cloud đều có access tới image mới nhất."

### 4.2 Kubernetes Manifests với Kustomize
**[Editor: k8s/deployments/overlays/]**

> **Lời thoại:**  
> "Em sử dụng **Kustomize** để quản lý configurations cho nhiều environments. Cùng một base manifest, nhưng:
> - **AWS overlay**: Sử dụng LoadBalancer type, kết nối RDS
> - **OpenStack overlay**: Sử dụng NodePort, cấu hình Internal DNS
>
> Điều này tuân thủ nguyên tắc **DRY** (Don't Repeat Yourself)."

### 4.3 ArgoCD GitOps Sync (Simulate)
**[Browser: ArgoCD UI hoặc Show diagram]**

> **Lời thoại:**  
> "**ArgoCD** liên tục watch GitOps repository. Khi Jenkins cập nhật image tag mới, ArgoCD sẽ:
> 1. Phát hiện **Desired State** thay đổi
> 2. So sánh với **Live State** trên cluster
> 3. Tự động **Sync** để 2 trạng thái khớp nhau
>
> Điều này đảm bảo **Single Source of Truth** - Git luôn là chủ đạo."

### 4.4 Cross-Cloud Verification
**[Terminal]**

```bash
# Kiểm tra pods trên AWS
kubectl --context=aws-eks get pods -n foodhub

# Kiểm tra pods trên OpenStack
kubectl --context=openstack-k8s get pods -n foodhub
```

> **Lời thoại:**  
> "Sau khi sync hoàn tất, em verify pods đang running trên cả 2 cloud. Các bạn thấy version mới đã được deploy thành công."

---

## 📊 PHẦN 5: MONITORING & OBSERVABILITY (2 phút)

### 5.1 Grafana Dashboard
**[Browser: Grafana]**

> **Lời thoại:**  
> "Hệ thống monitoring sử dụng **Prometheus Federation** để thu thập metrics từ cả 2 cloud về một Grafana duy nhất.
>
> Dashboard này hiển thị:
> - **CPU/Memory** usage của từng service
> - **Request rate** và **Error rate**
> - **Pod health status** cho cả AWS và OpenStack
>
> Ops team có thể monitor toàn bộ infrastructure từ một giao diện."

---

## 💥 PHẦN 6: RESILIENCE TEST (2 phút)

### 6.1 Simulate Pod Failure
**[Terminal]**

```bash
# Delete pod trên OpenStack
kubectl --context=openstack-k8s delete pod -l app=foodhub-users -n foodhub
```

> **Lời thoại:**  
> "Bây giờ em sẽ simulate sự cố bằng cách xóa một pod..."

**[Show: Pod tự động recreate]**

```bash
# Watch pods
kubectl --context=openstack-k8s get pods -n foodhub -w
```

> **Lời thoại:**  
> "Kubernetes **Deployment Controller** phát hiện pod bị thiếu và tự động tạo lại trong vài giây. Đây là khả năng **Self-Healing** của K8s.
>
> Trong production, nếu toàn bộ OpenStack cluster down, Load Balancer sẽ tự động route traffic sang AWS - đảm bảo **High Availability**."

---

## 📝 PHẦN 7: KẾT LUẬN (2 phút)

### 7.1 Tổng kết
**[Slide: Kết luận]**

> **Lời thoại:**  
> "Tóm lại, dự án đã đạt được các mục tiêu:
>
> ✅ **DevSecOps Pipeline** hoàn chỉnh với Trivy và SonarQube  
> ✅ **Hybrid Cloud Deployment** trên AWS và OpenStack  
> ✅ **GitOps Workflow** với ArgoCD  
> ✅ **Unified Monitoring** với Prometheus Federation  
> ✅ **High Availability** và Self-Healing  
>
> Pipeline này có thể áp dụng trực tiếp vào môi trường production của doanh nghiệp."

### 7.2 Hướng phát triển
> **Lời thoại:**  
> "Hướng phát triển tiếp theo:
> - Tích hợp **DAST** (Dynamic Application Security Testing)
> - Thêm **Service Mesh** (Istio) cho micro-segmentation
> - Implement **Chaos Engineering** với Litmus
>
> Em xin kết thúc phần trình bày. Cảm ơn Thầy/Cô và các bạn đã lắng nghe!"

---

## 🎯 Q&A DỰ KIẾN

### Câu hỏi phổ biến

**Q1: Tại sao chọn Jenkins thay vì GitHub Actions?**
> "Jenkins có khả năng customize cao hơn, hỗ trợ on-premise deployment, và có plugin ecosystem phong phú cho enterprise."

**Q2: VPN Site-to-Site có ảnh hưởng tới performance không?**
> "Có overhead nhẹ về latency (~10-20ms), nhưng đảm bảo encryption và security cho cross-cloud traffic."

**Q3: Làm sao handle database sync giữa 2 cloud?**
> "Trong thiết kế này, mỗi cloud có database riêng. Sync data sử dụng CDC (Change Data Capture) hoặc Event-Driven Architecture."

**Q4: Chi phí vận hành hệ thống này?**
> "AWS EKS: ~$200/tháng cho small cluster. OpenStack: Phụ thuộc vào phần cứng tự có. Pipeline tools: Open-source, không tốn license."

---

## ✅ CHECKLIST TRƯỚC KHI DEMO

- [ ] Docker Desktop đang chạy
- [ ] Internet ổn định
- [ ] Terminal có sẵn alias kubectl
- [ ] Browser tabs đã mở sẵn: Jenkins, SonarQube, Frontend
- [ ] Git credentials đã cache
- [ ] Backup video recording (phòng trường hợp fail)
- [ ] Slide presentation đã ready
- [ ] Nước uống đầy đủ 😄

---

> **Ghi chú**: File này dùng để tham khảo khi chuẩn bị và thực hiện demo. Có thể điều chỉnh thời lượng tùy theo yêu cầu của hội đồng.
