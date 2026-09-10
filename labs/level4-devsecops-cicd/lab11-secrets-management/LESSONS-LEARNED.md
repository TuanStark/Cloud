# 📚 BÀI HỌC THỰC CHIẾN: SECRETS MANAGEMENT & ZERO-TRUST ROTATION

> **Tài liệu đào tạo năng lực Senior DevSecOps Engineer (2–3 YoE)**  
> **Tác giả:** Lê Công Tuấn & Mentor DevSecOps  
> **Chủ đề:** AWS Secrets Manager, External Secrets Operator (ESO), IRSA Least-Privilege & Zero-Downtime Secret Rotation

---

## 🚫 1. Cạm Bẫy "Ảo Tưởng An Ninh" Base64 Trong Kubernetes

Khi phỏng vấn, nếu ứng viên nói: *"Dữ liệu nhạy cảm được em bảo vệ an toàn trong Kubernetes Secret vì nó đã được mã hóa thành chuỗi Base64"*, ứng viên đó sẽ bị đánh trượt ngay lập tức!

### Sự thật kỹ thuật:
* **Encoding (Mã hóa định dạng như Base64):** Chỉ là phép biến đổi biểu diễn nhị phân sang bảng mã ASCII để tránh lỗi ký tự đặc biệt khi truyền tải. **Không cần khóa bí mật, bất kỳ ai cũng dịch ngược được trong 1 microsecond bằng lệnh `base64 -d`**.
* **Encryption (Mã hóa mật mã học như AES-GCM-256):** Bắt buộc phải có Chìa khóa (KMS Key). Nếu không có khóa thì dữ liệu chỉ là một mớ hỗn độn vô nghĩa.
* Trong cụm Kubernetes mặc định, cơ sở dữ liệu `etcd` lưu trữ các Secret này dưới dạng văn bản thô. Bất kỳ ai dump được database etcd hoặc có quyền `kubectl get secret` đều xem được toàn bộ mật khẩu công ty.

---

## ⚖️ 2. So Sánh Hai Trường Phái: External Secrets Operator (ESO) vs CSI Driver

Trong thế giới doanh nghiệp, có 2 giải pháp kết nối Cloud Secrets vào Kubernetes. Bạn bắt buộc phải nắm rõ ưu/nhược điểm từng loại:

| Tiêu Chí | External Secrets Operator (ESO) 🏆 | Secrets Store CSI Driver |
| :--- | :--- | :--- |
| **Cách thức hoạt động** | Là một K8s Controller kéo secret từ AWS/Vault về và **tạo ra K8s Secret bản địa** trong namespace. | Mount secret trực tiếp từ AWS/Vault vào bộ nhớ RAM của Pod (`tmpfs`) dưới dạng file. |
| **Cách Pod tiêu thụ** | Cực kỳ linh hoạt: Dùng được cả **Biến môi trường (`envFrom`)** LẪN File mount. | Chủ yếu là **File mount**; muốn dùng biến môi trường phải bật thêm tính năng sync phụ trợ. |
| **Dấu chân trong etcd** | Có tạo Secret object trong etcd (cần bảo vệ bằng K8s RBAC và KMS). | **Zero Footprint**: Hoàn toàn không lưu secret vào etcd. |
| **Tính tương thích** | Tương thích 100% với toàn bộ hệ sinh thái Helm Charts và mã nguồn hiện có của công ty. | Đòi hỏi phải sửa cú pháp Deployment phức tạp (`volumeMounts`, `csi.driverPath`). |
| **Độ phổ biến thực tế** | **~75% doanh nghiệp chọn ESO** vì dễ tích hợp với các ứng dụng 12-factor microservices. | Thường dùng cho các hệ thống ngân hàng khắt khe cấm tiệt K8s Secret trong etcd. |

---

## 🔄 3. Vòng Đời 4 Bước Xoay Vòng Mật Khẩu (AWS Secret Rotation Protocol)

Khi bật tính năng tự động đổi mật khẩu định kỳ 30 ngày/lần trên AWS Secrets Manager, một hàm **AWS Lambda** sẽ thực hiện giao thức 4 bước an toàn tuyệt đối:

```
[BƯỚC 1: createSecret]
Tạo mật khẩu ngẫu nhiên mới và gán nhãn tạm: AWSPENDING.
         │
         ▼
[BƯỚC 2: setSecret]
Lambda kết nối vào Database bằng tài khoản Master và đổi mật khẩu cho user:
ALTER USER payment_app_user WITH PASSWORD 'new_random_password';
         │
         ▼
[BƯỚC 3: testSecret]
Lambda thử kết nối vào Database bằng 'new_random_password'.
Nếu thất bại -> Hủy bỏ rotation, giữ nguyên mật khẩu cũ để không làm gián đoạn hệ thống.
         │
         ▼
[BƯỚC 4: finishSecret]
Xác nhận thành công! Chuyển nhãn AWSPENDING thành AWSCURRENT.
Mật khẩu cũ bị chuyển thành AWSPREVIOUS (để rollback nếu cần).
```

### Làm sao Pod ứng dụng cập nhật mật khẩu mới mà không có Downtime?
1. ESO phát hiện version `AWSCURRENT` mới qua chu kỳ `refreshInterval` và cập nhật K8s Secret `payment-db-secret`.
2. Công cụ **Reloader Operator** (chạy ngầm trong cụm) phát hiện Secret thay đổi và kích hoạt lệnh:
   ```bash
   kubectl rollout restart deployment payment-api-deployment -n payment
   ```
3. Kubernetes tạo các Pod mới nạp mật khẩu mới, kiểm tra `livenessProbe` và `readinessProbe` thành công thì mới tắt các Pod cũ. **Quá trình chuyển đổi diễn ra hoàn toàn êm ái (Zero-Downtime)**!

---

## 🛡️ 4. Bảng So Sánh Tư Duy: Junior vs Senior Về Quản Lý Bí Mật

| Khía Cạnh | Junior Developer / DevOps | Senior / Principal DevSecOps |
| :--- | :--- | :--- |
| **Nơi lưu mật khẩu** | Lưu trong file `.env`, file cấu hình hoặc hardcode thẳng vào repo git private. | Tập trung vào **AWS Secrets Manager / HashiCorp Vault**, mã hóa tĩnh bằng KMS. |
| **Cấp quyền cho Pod** | Tạo AWS Access Key tĩnh (AKIA...) rồi nhét vào biến môi trường của Pod. | Áp dụng **IRSA (IAM Roles for Service Accounts)**; Pod dùng token OIDC tự hủy sau 1 giờ. |
| **Phạm vi IAM Policy** | Viết `secretsmanager:*` trên resource `*` để "chạy được cho nhanh". | Chỉ cấp `GetSecretValue` trên đúng ARN `/prod/payment/*` và `kms:Decrypt` trên đúng KMS Key. |
| **Xoay vòng mật khẩu** | Không bao giờ đổi mật khẩu cho đến khi bị hack hoặc nhân viên nghỉ việc mới đi đổi tay. | Bật **Automatic Rotation** định kỳ 30 ngày qua Lambda và đồng bộ tự động qua ESO + Reloader. |
| **Kiểm toán an ninh** | Không biết ai đã xem mật khẩu, không có nhật ký truy vết. | Kích hoạt **AWS CloudTrail**: Mọi lượt gọi API đọc mật khẩu đều lưu vết kèm IP, User, Timestamp. |

---

## 🎯 5. Bộ Câu Hỏi Phỏng Vấn DevSecOps (2-3 YoE) Về Secrets Management

### Câu hỏi 1: "Tại sao nên dùng IRSA (IAM Roles for Service Accounts) thay vì gán IAM Role trực tiếp vào EC2 Worker Node?"
> **Câu trả lời chuẩn Senior:**  
> "Nếu ta gán quyền đọc secret vào IAM Role của Worker Node (EC2 Instance Profile), thì **TẤT CẢ các Pod khác** cùng chạy trên Node đó (kể cả Pod của đội khác hoặc Pod bị nhiễm mã độc) đều có thể gọi Metadata API `169.254.169.254` để trộm quyền đọc secret của Payment!  
> Sử dụng **IRSA** giúp gắn chặt quyền IAM vào từng **ServiceAccount cụ thể của Pod**. Chỉ Pod nào có đúng ServiceAccount đó mới nhận được OIDC Token được AWS STS cấp quyền, tuân thủ tuyệt đối nguyên tắc Least Privilege và phân tách cô lập tài nguyên."

### Câu hỏi 2: "Sự khác biệt lớn nhất giữa AWS Parameter Store và AWS Secrets Manager là gì? Khi nào nên dùng loại nào?"
> **Câu trả lời chuẩn Senior:**  
> "1. **AWS Parameter Store (SSM):** Phù hợp với các cấu hình thông thường (Log level, feature flags, URL) và các secret đơn giản. Chi phí rẻ (Standard tier miễn phí), nhưng **không hỗ trợ tính năng tự động xoay vòng mật khẩu (Automatic Rotation)**.  
> 2. **AWS Secrets Manager:** Thiết kế chuyên dụng cho các bí mật quan trọng (Database credentials, API keys). Có sẵn tính năng tích hợp xoay vòng mật khẩu tự động qua Lambda cho RDS/Aurora, quản lý phiên bản (AWSCURRENT, AWSPENDING) và cross-account secret sharing. Chi phí $0.40/secret/tháng nhưng mang lại sự an toàn tuyệt đối cho hệ thống tài chính/thanh toán."
