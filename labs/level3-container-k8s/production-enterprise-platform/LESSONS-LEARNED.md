# 📚 BÀI HỌC KINH NGHIỆM: CAPSTONE LEVEL 3 - ENTERPRISE CLOUD-NATIVE PLATFORM TRÊN AWS EKS
## Cẩm Nang Thực Chiến Cấp Principal DevSecOps (Hành Trang Vững Chắc Đạt Chuẩn 2–3 Năm Kinh Nghiệm)

---

## 1. Dịch vụ & Khái niệm Cốt lõi (Core Concepts)

Khi một Fullstack Developer chuyển mình sang vị trí **Cloud / DevSecOps Engineer (2–3 năm kinh nghiệm)**, bước nhảy vọt quan trọng nhất không nằm ở việc nhớ thuộc lòng cú pháp lệnh, mà nằm ở **Tư Duy Thiết Kế Hạ Tầng Chịu Lỗi (Fault-Tolerant & Resilient Architecture)**.

Trong môi trường Production thực tế, hệ thống hạ tầng đám mây luôn vận hành trên định luật Murphy: *"Bất cứ điều gì có thể hỏng, nó sẽ hỏng vào thời điểm tồi tệ nhất"*. Máy chủ EC2 có thể bị tắt bất ngờ, đường truyền cáp quang của một Data Center AWS có thể bị đứt, và hacker luôn tìm cách rà quét mọi cổng dịch vụ 24/7.

Dự án Capstone này đã hợp nhất toàn diện 3 bài lab nền tảng (Lab 07: Container Security, Lab 08: EKS Terraform, Lab 09: Ingress & IRSA) thành một **hệ sinh thái Production hoàn chỉnh** dựa trên 5 trụ cột sinh tử:
1. **Zero-Downtime Rolling Updates:** Triệt tiêu hoàn toàn lỗi 502/504 khi triển khai phiên bản mới bằng cách kết hợp `preStop` hook, Readiness probe và `PodDisruptionBudget`.
2. **Multi-AZ Blast Radius Containment:** Ép buộc phân tán Pods qua nhiều Availability Zones độc lập bằng `topologySpreadConstraints`.
3. **Zero-Trust Micro-segmentation:** Khóa cứng mạng nội bộ Kubernetes bằng `NetworkPolicy`, biến mỗi microservice thành một pháo đài cô lập.
4. **Cloud-Native Identity Federation:** Cấp phát quyền ngắn hạn cho Pod tương tác với AWS S3 qua OIDC + IRSA, khai tử vĩnh viễn long-lived credentials.
5. **FinOps & Autoscaling Balancing:** Quản lý tài nguyên QoS Burstable kết hợp HPA v2 và S3 Lifecycle Rules tối ưu chi phí lưu trữ dài hạn.

---

## 2. Định nghĩa Kỹ thuật Chuẩn (Formal Definition)

### A. Vòng Đời Tắt Pod & Cạm Bẫy `preStop` Hook (The Pod Termination Lifecycle)
- **Cơ chế mặc định của Kubernetes:**
  Khi một Pod bị xóa (do rolling update hoặc scale down):
  1. Kubernetes API Server đổi trạng thái Pod thành `Terminating`.
  2. Đồng thời phát hai hành động song song bất đồng bộ:
     - **Hành động 1:** Gỡ IP của Pod ra khỏi Kubernetes Endpoints / AWS ALB Target Group.
     - **Hành động 2:** Gửi tín hiệu `SIGTERM` tới container trong Pod.
- **Cạm bẫy thực tế (The Race Condition):**
  AWS Load Balancer Controller và kube-proxy mất từ **3 đến 7 giây** để nhận diện và cập nhật bảng định tuyến iptables / ALB Target Group. Trong khoảng thời gian trễ này, ALB **vẫn tiếp tục gửi request của khách hàng** vào Pod! Nhưng container lúc này đã nhận `SIGTERM` và đang tắt máy -> Khách hàng lập tức nhận mã lỗi **502 Bad Gateway** hoặc **Connection Refused**!
- **Giải pháp chuẩn Enterprise:**
  Cấu hình `lifecycle.preStop.exec.command: ["/bin/sh", "-c", "sleep 5"]`. Lệnh này ép container hoãn việc xử lý `SIGTERM` trong 5 giây, giữ tiến trình tiếp tục phục vụ nốt các request cuối cùng trong khi ALB hoàn tất việc gỡ bỏ IP Pod khỏi hệ thống!

### B. `TopologySpreadConstraints` vs `PodAntiAffinity`
- **Phương pháp cũ (`podAntiAffinity`):** Cấm hai Pod cùng chạy chung một Node hoặc Zone. Nhược điểm: Rất thô bạo (All-or-Nothing), nếu cụm thiếu Node thì Pod sẽ bị treo ở trạng thái `Pending` vĩnh viễn, không thể tự cân bằng linh hoạt.
- **Chuẩn hiện đại (`topologySpreadConstraints`):**
  - Sử dụng tham số `maxSkew: 1` và `topologyKey: topology.kubernetes.io/zone`.
  - **Ý nghĩa:** Chênh lệch số lượng Pod giữa bất kỳ hai Availability Zones nào không bao giờ vượt quá 1. 
  - Đảm bảo tải lượng luôn được san đều 50-50 trên `us-east-1a` và `us-east-1b`. Nếu một AZ sập hoàn toàn, 50% số Pod ở AZ còn lại vẫn xử lý giao dịch bình thường mà không bị gián đoạn.

### C. `PodDisruptionBudget` (PDB) - Hợp Đồng Cam Kết SLA
- **Định nghĩa:** PDB là chính sách bảo vệ chống lại các sự cố gián đoạn có chủ đích (Voluntary Disruptions) như: kỹ sư chạy lệnh `kubectl drain`, Cluster Autoscaler thu hồi Node thừa, hoặc AWS tự động cập nhật hệ điều hành máy chủ Worker Node.
- **Cấu hình `minAvailable: 1`:** Cam kết với Kubernetes Scheduler rằng trong mọi hoàn cảnh bảo trì, **luôn luôn phải có ít nhất 1 Pod đang ở trạng thái Ready** trước khi được phép hạ bệ Pod cũ.

### D. Zero-Trust NetworkPolicy (Micro-segmentation)
- **Định nghĩa:** Lớp tường lửa phần mềm L3/L4 hoạt động trực tiếp trên card mạng ảo của từng Pod, được thực thi bởi CNI (AWS VPC CNI Network Policy Controller).
- **Mô hình Defense-in-Depth:**
  1. `default-deny-all-ingress`: Khóa toàn bộ cổng.
  2. `allow-ingress-to-frontend`: Chỉ mở cổng 8080 cho Ingress ALB.
  3. `allow-frontend-to-backend`: Chỉ mở cổng 5000 cho các Pod có nhãn `app: order-frontend`.
  4. Mọi Pod khác trong cụm (kể cả Pod của hacker nếu chiếm được namespace khác) đều không thể ping hay gửi bất kỳ gói tin nào vào Backend.

### E. Pod Security Standards (PSS) - Cấp Độ `restricted`
- **Định nghĩa:** Cơ chế kiểm soát an ninh tích hợp sẵn của Kubernetes Admission Controller thay thế cho PodSecurityPolicy (PSP) cũ.
- **Cấp độ `restricted`:** Ép buộc 100% Pods phải:
  - Chạy bằng Non-Root User (`runAsNonRoot: true`, `UID >= 1000`).
  - Khóa cứng hệ thống tệp tin (`readOnlyRootFilesystem: true`).
  - Tước bỏ toàn bộ đặc quyền kernel (`capabilities.drop: ["ALL"]`).
  - Chặn đứng hoàn toàn nguy cơ Container Escape và Reverse Shell.

---

## 3. Giải thích Dễ hiểu & Ẩn dụ Thực tế (Metaphors)

| Khái niệm Production | Ẩn dụ Đời sống Thực tế | Ý nghĩa Kỹ thuật Trong Vận Hành |
| :--- | :--- | :--- |
| **`preStop: sleep 5`** | Nhân viên quầy vé thông báo "Chuẩn bị đóng quầy", đứng bấm vé nốt cho 3 vị khách đang xếp hàng rồi mới hạ rèm. | Không ngắt kết nối thô bạo; chờ Load Balancer điều hướng khách sang quầy khác rồi mới tắt container. |
| **`PodDisruptionBudget`** | Quy định của bệnh viện: Dù bác sĩ có đến giờ đổi ca trực, luôn phải có ít nhất 1 bác sĩ túc trực tại phòng cấp cứu. | Ngăn chặn việc lệnh `kubectl drain` tắt sạch toàn bộ Pods cùng lúc làm sập hệ thống. |
| **`TopologySpread`** | Không bao giờ để toàn bộ tiền và giấy tờ tùy thân vào cùng một ngăn balo khi đi du lịch nước ngoài. | Phân tán Pods sang 2 Data Center độc lập; cháy trạm biến áp ở Data Center này thì Data Center kia vẫn sống. |
| **Zero-Trust NetworkPolicy** | Khách sạn cao cấp: Khách tầng nào chỉ được dùng thẻ quẹt lên tầng đó, không thể đi lung tung gõ cửa phòng người khác. | Cô lập microservice; hacker chiếm được frontend cũng không thể tự do mò vào backend hay database. |
| **Read-Only Root Filesystem** | Khách thuê nhà chỉ được ở, toàn bộ tường, sàn, cửa sổ đều bị đổ bê tông niêm phong, không được đóng đinh hay sơn sửa. | Hacker dù có tìm ra lỗ hổng web cũng không thể ghi file shell độc hại (`/evil.sh`) vào container. |

---

## 4. Bộ 10 Tiêu Chuẩn Vàng Kèm Code Demo Thực Chiến (So Sánh Trực Quan)

Dưới đây là 10 tiêu chuẩn phân định giữa một kỹ sư làm bài tập mẫu và một **Kỹ sư Cloud / DevSecOps 2–3 năm kinh nghiệm thực chiến**:

---

### Tiêu Chuẩn 1: Vùng Cách Ly Pod Security Standards (PSS) Restricted
*Khóa cứng toàn bộ quyền root từ tầng Namespace Admission Controller.*

❌ **Code Ngây Thơ (Namespace Không Có Rào Chắn):**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: app-dev
  # Bất kỳ ai cũng có thể deploy container chạy root UID 0, đe dọa toàn bộ cụm!
```

✅ **Code Chuẩn Enterprise (PSS Restricted Enforcement):**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production-ecommerce
  labels:
    name: production-ecommerce
    # Chặn đứng mọi Pod vi phạm bảo mật ngay tại cửa ngõ API Server
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

---

### Tiêu Chuẩn 2: Multi-AZ High Availability (`topologySpreadConstraints`)
*Chống sập toàn bộ hệ thống khi 1 Data Center của AWS bị mất điện.*

❌ **Code Ngây Thơ (Xếp Ngẫu Nhiên, Dễ Chết Chùm):**
```yaml
spec:
  replicas: 2
  # Scheduler có thể dồn cả 2 Pods vào chung 1 Zone (us-east-1a)!
```

✅ **Code Chuẩn Enterprise (Cân Bằng 50-50 Đa Vùng):**
```yaml
spec:
  replicas: 2
  template:
    spec:
      topologySpreadConstraints:
        - maxSkew: 1                             # Chênh lệch giữa 2 zone tối đa là 1
          topologyKey: topology.kubernetes.io/zone # Tiêu chí chia theo Availability Zone
          whenUnsatisfiable: DoNotSchedule       # Không thỏa mãn thì không xếp bừa
          labelSelector:
            matchLabels:
              app: order-backend
```

---

### Tiêu Chuẩn 3: Cặp Đôi Probes Tách Biệt (`/healthz` vs `/ready`)
*Phân định rõ ràng: "Tiến trình còn sống?" và "Có sẵn sàng nhận khách?".*

❌ **Code Ngây Thơ (Dùng Chung 1 Probe Gây Restart Oan):**
```yaml
# Dùng chung 1 endpoint / cho cả liveness và readiness
livenessProbe:
  httpGet:
    path: /
    port: 5000
```

✅ **Code Chuẩn Enterprise (Tách Rời Hoàn Toàn):**
```yaml
# Liveness: Chỉ restart container khi bị treo luồng / Deadlock
livenessProbe:
  httpGet:
    path: /healthz
    port: 5000
  initialDelaySeconds: 10
  periodSeconds: 10

# Readiness: Chỉ điều tiết traffic, ngắt kết nối khi đang shutdown
readinessProbe:
  httpGet:
    path: /ready
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 5
```
Đi kèm logic trong `server.js`:
```javascript
let isShuttingDown = false;

app.get('/ready', (req, res) => {
  if (isShuttingDown) {
    // Trả về 503 ngay lập tức để K8s rút IP Pod ra khỏi Service/Ingress
    return res.status(503).json({ status: 'shutting_down' });
  }
  res.status(200).json({ status: 'ready' });
});
```

---

### Tiêu Chuẩn 4: Trì Hoãn Tắt Máy Bằng `preStop: sleep 5` (Zero-Downtime)
*Loại bỏ 100% lỗi 502 Bad Gateway trong quá trình Rolling Update.*

❌ **Code Ngây Thơ (Tắt Máy Ngay Lập Tức Làm Rớt Request):**
```yaml
spec:
  containers:
    - name: backend
      image: backend:v1
      # Không có preStop hook -> Nhận SIGTERM là tắt ngay
```

✅ **Code Chuẩn Enterprise (Đợi 5s Rút IP Xong Mới Tắt):**
```yaml
spec:
  containers:
    - name: backend
      image: backend:v2
      lifecycle:
        preStop:
          exec:
            # Giữ container sống thêm 5s để xử lý nốt request dở dang
            command: ["/bin/sh", "-c", "sleep 5"]
```

---

### Tiêu Chuẩn 5: Quản Trị Tài Nguyên QoS Burstable (Chống OOMKilled Dây Chuyền)
*Không để 1 Pod bị memory leak kéo sập toàn bộ máy chủ EC2.*

❌ **Code Ngây Thơ (Không Giới Hạn Tài Nguyên):**
```yaml
spec:
  containers:
    - name: backend
      # Pod có thể ăn sạch 100% RAM và CPU của máy chủ host!
```

✅ **Code Chuẩn Enterprise (QoS Burstable Phân Bổ Chặt Chẽ):**
```yaml
spec:
  containers:
    - name: backend
      resources:
        requests:
          cpu: 100m     # Cam kết tối thiểu 0.1 Core CPU
          memory: 128Mi # Cam kết tối thiểu 128MB RAM
        limits:
          cpu: 500m     # Giới hạn tối đa 0.5 Core CPU (tránh ngốn CPU node)
          memory: 256Mi # Bị tiêu diệt ngay nếu vượt quá 256MB (bảo vệ Pods khác)
```

---

### Tiêu Chuẩn 6: Hợp Đồng Cam Kết SLA Bằng `PodDisruptionBudget`
*Bảo vệ ứng dụng không bị sập khi kỹ sư chạy lệnh `kubectl drain`.*

❌ **Nếu Không Có PDB:**
```bash
# Khi chạy lệnh bảo trì máy chủ:
kubectl drain ip-10-0-11-25.ec2.internal --ignore-daemonsets
# -> K8s tắt sạch toàn bộ Pods backend cùng lúc! Ứng dụng sập hoàn toàn!
```

✅ **Code Chuẩn Enterprise (Luôn Bảo Toàn Tối Thiểu 1 Pod Sống):**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: backend-pdb
  namespace: production-ecommerce
spec:
  minAvailable: 1 # Ép K8s phải đợi Pod mới ở Node khác Ready xong mới được tắt Pod cũ
  selector:
    matchLabels:
      app: order-backend
```

---

### Tiêu Chuẩn 7: Ingress ALB Với Target-Type `ip` (AWS VPC CNI)
*Tối ưu độ trễ và bảo toàn 100% Client Source IP thực.*

❌ **Code Ngây Thơ (`target-type: instance`):**
```yaml
# Mặc định đi qua NodePort -> kube-proxy iptables -> mất IP khách, tăng 10ms độ trễ
annotations:
  alb.ingress.kubernetes.io/target-type: instance
```

✅ **Code Chuẩn Enterprise (`target-type: ip`):**
```yaml
annotations:
  kubernetes.io/ingress.class: alb
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: ip # Bắn thẳng vào card mạng ENI của Pod
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
  alb.ingress.kubernetes.io/ssl-redirect: '443'
  alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
```

---

### Tiêu Chuẩn 8: Phân Quyền Pod Đám Mây Bằng IRSA (Zero Long-Lived Keys)
*Không hardcode secret trong mã nguồn, không lạm dụng Node Role.*

❌ **Code Nguy Hiểm (Lưu Access Key Trong Môi Trường / ConfigMap):**
```yaml
env:
  - name: AWS_ACCESS_KEY_ID
    value: "AKIAIOSFODNN7EXAMPLE" # CỰC KỲ NGUY HIỂM: Bị lộ là bay tài khoản!
  - name: AWS_SECRET_ACCESS_KEY
    value: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

✅ **Code Chuẩn Enterprise (OIDC Web Identity Federation):**
```yaml
# 1. ServiceAccount mang annotation IRSA
apiVersion: v1
kind: ServiceAccount
metadata:
  name: order-backend-sa
  namespace: production-ecommerce
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/ecommerce-backend-irsa-prod"
```
Kết hợp cùng Trust Policy chặt chẽ trong Terraform (`irsa.tf`):
```hcl
condition {
  test     = "StringEquals"
  variable = "${local.oidc_issuer}:sub"
  values   = ["system:serviceaccount:production-ecommerce:order-backend-sa"]
}
```

---

### Tiêu Chuẩn 9: FinOps Tối Ưu Hóa Chi Phí Lưu Trữ S3 Tự Động
*Tự động dọn dẹp và nén chứng từ cũ, giảm 68% chi phí hàng tháng.*

❌ **Code Không Có Lifecycle (Hóa Đơn Lưu Trữ Tăng Đều Theo Thời Gian):**
```hcl
resource "aws_s3_bucket" "invoices" {
  bucket = "company-invoices"
  # Để dữ liệu ở S3 Standard vĩnh viễn với giá đắt đỏ $0.023/GB/tháng
}
```

✅ **Code Chuẩn FinOps Enterprise (Tự Động Chuyển Tầng Lưu Trữ):**
```hcl
resource "aws_s3_bucket_lifecycle_configuration" "invoices" {
  bucket = aws_s3_bucket.invoices.id

  rule {
    id     = "archive-old-invoices"
    status = "Enabled"
    filter { prefix = "invoices/" }

    # Sau 30 ngày: Ít đọc -> Chuyển sang Standard-IA ($0.0125/GB, giảm 50%)
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Sau 90 ngày: Lưu chứng từ thuế -> Chuyển sang Glacier ($0.004/GB, giảm 68%)
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}
```

---

### Tiêu Chuẩn 10: Khóa Cứng Root Filesystem Kết Hợp EmptyDir Cho `/tmp`
*Triệt tiêu hoàn toàn khả năng cài mã độc hoặc backdoor vào container.*

❌ **Code Mặc Định (Cho Phép Ghi Đè Mọi Thư Mục):**
```yaml
securityContext:
  # Hacker tải script độc vào /app hoặc /bin và thực thi chiếm quyền
```

✅ **Code Chuẩn Enterprise (Read-Only Root Filesystem + EmptyDir):**
```yaml
spec:
  volumes:
    - name: tmp-volume
      emptyDir: {} # Volume tạm thời chỉ tồn tại trên RAM của Node

  containers:
    - name: backend
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true # Khóa cứng toàn bộ ổ đĩa chỉ đọc
        capabilities:
          drop: ["ALL"]              # Tước bỏ toàn bộ Linux capabilities

      volumeMounts:
        - name: tmp-volume
          mountPath: /tmp            # Chỉ cho phép ghi file tạm vào /tmp
```

---

## 5. Bài Học Xương Máu & Những Câu Chuyện Thảm Họa Thực Tế (Horror Stories)

### 💀 Horror Story 1: Thảm Họa "Flash Sale 502" Vì Thiếu `preStop` Hook
- **Bối cảnh:** Một sàn thương mại điện tử triển khai chiến dịch giảm giá nửa đêm. Lượng truy cập tăng vọt, đội ngũ DevOps quyết định release một hotfix để tối ưu giao diện thanh toán.
- **Sự cố:** Khi chạy rolling update, Kubernetes lập tức gửi `SIGTERM` tới các Pod cũ. Do ứng dụng Node.js đóng server ngay lập tức trong khi AWS Application Load Balancer mất 5 giây mới rút IP ra khỏi Target Group, hơn **15,000 khách hàng** đang bấm nút "Thanh Toán" nhận về mã lỗi `502 Bad Gateway`! Doanh nghiệp thiệt hại ước tính hơn 2 tỷ đồng chỉ trong 10 phút.
- **Khắc phục:** Thêm `preStop: sleep 5` và cờ `isShuttingDown` trong mã nguồn. Ở lần release sau, tỷ lệ lỗi 502 giảm về **con số 0 tuyệt đối**.

### 💀 Horror Story 2: Thảm Họa Sập Toàn Bộ Hệ Thống Khi AWS Mất Điện 1 Data Center
- **Bối cảnh:** Công ty Fintech triển khai 4 replicas cho Core Banking API trên cụm EKS gồm 4 Worker Nodes. Tuy nhiên, lập trình viên không khai báo `topologySpreadConstraints`.
- **Sự cố:** Do thuật toán sắp xếp ngẫu nhiên của scheduler, cả 4 Pods đều vô tình được xếp lên các Node nằm trong cùng một Availability Zone `ap-southeast-1a`. Một buổi sáng, trạm biến áp của AWS tại zone 1a gặp sự cố sét đánh, zone này bị ngắt điện khẩn cấp. Mặc dù công ty mua cụm EKS Multi-AZ, toàn bộ 4 Pods chết sạch cùng lúc, dịch vụ ngân hàng tê liệt suốt 45 phút!
- **Khắc phục:** Bắt buộc áp dụng `topologySpreadConstraints` với `maxSkew: 1` và `whenUnsatisfiable: DoNotSchedule`. Pods được ép buộc phân bổ đều 50-50, một zone chết thì zone kia vẫn gánh tải hoàn hảo.

### 💀 Horror Story 3: Hacker Dò Quét Toàn Bộ Mạng Nội Bộ Vì Mạng Phẳng (Flat Network)
- **Bối cảnh:** Một công ty SaaS cho phép nhân viên deploy các Pod thử nghiệm vào cụm Kubernetes nội bộ. Mạng trong cụm để mặc định (không có NetworkPolicy).
- **Sự cố:** Một Pod chạy ứng dụng demo của intern sử dụng thư viện log dính lỗ hổng Log4j / RCE. Hacker chiếm quyền shell của Pod này. Từ Pod đó, hacker dùng lệnh `nmap` quét toàn bộ dải mạng `10.0.0.0/16` của cụm, tìm thấy cổng `5000` của Backend thanh toán và cổng `5432` của Database nội bộ vốn không có mật khẩu mạnh. Toàn bộ cơ sở dữ liệu bị mã hóa đòi tiền chuộc!
- **Khắc phục:** Kích hoạt ngay lập tức bộ quy tắc **Micro-segmentation NetworkPolicy**: Default Deny toàn bộ, chỉ cho phép luồng dữ liệu hợp lệ duy nhất từ Frontend -> Backend. Hacker dù có chiếm được một Pod cũng bị nhốt trong "căn phòng kín", không thể gửi bất kỳ gói tin nào sang Pod bên cạnh.

---

## 💡 Bảng Đối Chiếu Tư Duy Toàn Diện

| Đặc Tính Kỹ Thuật | Code Tutorial / Junior ("Chạy Được Là Xong") | Code Enterprise / Senior ("Bảo Mật & Chịu Lỗi") |
| :--- | :--- | :--- |
| **Namespace Security** | Namespace `default` không có bảo vệ | Nhãn PSS `enforce: restricted` chặn đứng mọi vi phạm |
| **User Chạy App** | `root` (`UID 0`) | `USER node` (UID 1000) / Non-root PSS Restricted |
| **Tệp Tin Ổ Đĩa** | Cho phép đọc/ghi tự do | `readOnlyRootFilesystem: true` + `emptyDir` mount `/tmp` |
| **Quyền AWS Cloud** | Hardcode Access Key trong `.env` hoặc gán quyền Node Role | **IRSA** (Gán IAM Role cho K8s ServiceAccount qua OIDC) |
| **Phân Bổ Vùng** | Để Kubernetes tự xếp ngẫu nhiên | `topologySpreadConstraints` ép buộc cân bằng đa AZ 50-50 |
| **Bảo Trì Node** | Tắt sạch Pods gây sập hệ thống | `PodDisruptionBudget` bảo toàn `minAvailable: 1` |
| **Dừng Tiến Trình** | Để K8s bắn `SIGKILL` làm rớt request | `preStop: sleep 5` + Graceful Shutdown rút IP an toàn |
| **Tự Động Co Giãn** | Canh me bằng tay để tăng replicas | **HPA v2** tự động co giãn theo ngưỡng CPU 70% / Mem 80% |
| **Định Tuyến Ingress** | Dùng NodePort hoặc mở nhiều cổng rời rạc | **L7 Ingress Path-based Routing** + TLS 1.3 qua chung 1 domain |
