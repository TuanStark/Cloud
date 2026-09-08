# 📚 BÀI HỌC KINH NGHIỆM: LEVEL 3 - LAB 08 (ENTERPRISE AWS EKS CLUSTER WITH TERRAFORM)

---

## 1. Dịch vụ & Khái niệm Cốt lõi (Core Concepts)

AWS Elastic Kubernetes Service (EKS) là dịch vụ điều phối container cấp doanh nghiệp hàng đầu thế giới, vận hành trên mô hình **Phân chia Trách nhiệm (Shared Responsibility Model)**:
- **AWS chịu trách nhiệm (Control Plane):** Độ sẵn sàng cao (Multi-AZ), sao lưu etcd, tự động vá lỗi bảo mật Kubernetes API server, controller-manager, scheduler với SLA 99.95%.
- **Kỹ sư Cloud/DevSecOps chịu trách nhiệm (Data Plane & Operations):** Quản lý VPC Networking, Managed Node Groups, OS Patching, Pod IP Allocation (VPC CNI), Cluster Logging, KMS Secret Encryption và phân quyền RBAC/IAM.

Bài lab này trang bị toàn diện tư duy và kỹ năng xây dựng cụm EKS chuẩn Production bằng Terraform:
1. **Mạng VPC Tương Thích EKS & Tagging Contract:** Quy chuẩn gắn tag cho Subnet để AWS Load Balancer Controller và Auto Scaling Group nhận diện.
2. **KMS Envelope Encryption:** Mã hóa bí mật Kubernetes (Secrets) tại tầng lưu trữ etcd bằng AWS Key Management Service.
3. **EKS Access Entries (Chuẩn 2026):** Cơ chế quản lý quyền Kubernetes bằng Native AWS API, khai tử phương thức quản lý qua file `aws-auth` ConfigMap đầy rủi ro.
4. **Hardened EC2 Launch Templates (IMDSv2):** Chống tấn công đánh cắp token từ Instance Metadata Service bằng cách ép buộc IMDSv2 và giới hạn hop limit = 2.
5. **Full CloudWatch Audit Logging:** Kích hoạt toàn bộ 5 loại log (api, audit, authenticator, controllerManager, scheduler) để đáp ứng chuẩn tuân thủ SOC 2 / ISO 27001.

---

## 2. Định nghĩa Kỹ thuật Chuẩn (Formal Definition)

### A. EKS Subnet Tagging Contract
- **Định nghĩa:** AWS Load Balancer Controller dựa hoàn toàn vào các AWS Resource Tags trên Subnet để tự động khám phá (Auto-discovery) hạ tầng mạng:
  - **Public Subnet:** `"kubernetes.io/role/elb" = "1"` (Chỉ định nơi tạo Internet-facing Application Load Balancer / NLB).
  - **Private Subnet:** `"kubernetes.io/role/internal-elb" = "1"` (Chỉ định nơi tạo Internal Load Balancer cho microservices nội bộ).
  - **Tag định danh Cluster:** `"kubernetes.io/cluster/<cluster-name>" = "shared"` (hoặc `"owned"`).
- **Hệ quả nếu thiếu:** Ingress Controller văng lỗi `could not discover subnets, no subnets matched` và từ chối tạo Load Balancer.

### B. KMS Envelope Encryption cho Kubernetes Secrets
- **Định nghĩa:** Mặc định trong Kubernetes thuần, đối tượng Secret chỉ được encode dưới dạng **Base64** và lưu trữ dưới dạng plain-text trong cơ sở dữ liệu `etcd`. Bất kỳ ai có quyền truy cập ổ đĩa hoặc snapshot của etcd đều có thể đọc trọn vẹn password và private keys.
- **KMS Envelope Encryption:** EKS tích hợp trực tiếp với AWS KMS. Khi một Secret được ghi vào etcd, EKS sinh ra một Data Key (DEK), mã hóa Secret bằng DEK, sau đó mã hóa DEK bằng KMS Customer Master Key (CMK). Khi đọc ra, quá trình giải mã diễn ra hoàn toàn trong bộ nhớ RAM của API Server.

### C. EKS Access Entries (API-Driven RBAC)
- **Định nghĩa:** Phương thức ủy quyền (Authentication/Authorization) hiện đại nhất của AWS EKS thay thế cho `aws-auth` ConfigMap.
- **Cơ chế:** Cho phép gán trực tiếp IAM Principal (IAM User/Role) với các Kubernetes Access Policies (`AmazonEKSClusterAdminPolicy`, `AmazonEKSAdminPolicy`, `AmazonEKSViewPolicy`) thông qua AWS API / Terraform (`aws_eks_access_entry` và `aws_eks_access_policy_association`).
- **Lợi ích:** Loại bỏ nguy cơ race condition, syntax error làm corrupt file ConfigMap dẫn đến lockout toàn bộ đội ngũ kỹ thuật khỏi cụm EKS.

### D. IMDSv2 Hardening trong Launch Template
- **Định nghĩa:** Instance Metadata Service phiên bản 2 (IMDSv2) là cơ chế bảo vệ máy chủ EC2 Worker Node trước các cuộc tấn công SSRF (Server-Side Request Forgery).
- **Cấu hình chuẩn EKS:**
  - `http_tokens = "required"`: Ép buộc mọi request lấy metadata phải có session token (PUT request trước với header `X-aws-ec2-metadata-token-ttl-seconds`).
  - `http_put_response_hop_limit = 2`: **Bắt buộc = 2 cho EKS**. Nếu để mặc định = 1, gói tin IP từ Pod chạy trong container (đã qua 1 network hop của bridge/veth) sẽ bị drop, khiến các Pod sử dụng IRSA hoặc AWS SDK không thể giao tiếp với IMDS!

---

## 3. Giải thích Dễ hiểu & Ẩn dụ Thực tế (Metaphors)

| Khái niệm EKS | Ẩn dụ Đời sống | Ý nghĩa Thực tế trong Vận hành |
| :--- | :--- | :--- |
| **Control Plane (EKS Managed)** | Ban Quản lý Tòa nhà chuyên nghiệp: bảo vệ, lễ tân, camera, hệ thống điện nước do nhà cung cấp lo trọn gói. | AWS tự động backup etcd, vá lỗ hổng Kubernetes API, tự phục hồi khi node master chết mà không làm gián đoạn ứng dụng. |
| **Data Plane (Worker Nodes)** | Các căn hộ cho thuê trong tòa nhà: nội thất, đồ đạc bên trong do người thuê tự sắm và tự bảo quản. | Đội ngũ DevOps tự chọn loại EC2 (`t3.medium`, `c6i.xlarge`), tự cấu hình dung lượng ổ cứng gp3, tự quản lý scaling. |
| **Subnet Tags (`role/elb=1`)** | Biển chỉ dẫn "Bãi đỗ xe dành cho khách vãng lai" và "Bãi đỗ xe nội bộ cư dân". | AWS Ingress Controller nhìn vào biển hiệu này để biết thả Public ALB vào subnet nào và Internal ALB vào đâu. |
| **Base64 vs KMS Encryption** | Base64 giống như cất tiền trong ví trong suốt: ai đi ngang qua cũng nhìn thấy mệnh giá. KMS giống như cất tiền vào két sắt 3 lớp mã số. | Base64 chỉ là encoding (không bảo vệ được dữ liệu). KMS biến Secret thành các khối ciphertext không thể đọc nếu không có khóa. |
| **`aws-auth` ConfigMap** | Một cuốn sổ tay ghi chép tên khách ra vào đặt tại bàn lễ tân: ai muốn sửa gì thì tẩy xóa trong sổ. | Rất dễ bị ai đó ghi đè, làm rách sổ hoặc viết sai format khiến bảo vệ đuổi hết khách ra ngoài (Cluster Lockout). |
| **EKS Access Entries** | Hệ thống thẻ từ tích hợp vân tay điện tử kết nối thẳng về cơ sở dữ liệu trung tâm của tập đoàn. | Cấp quyền hoặc thu hồi quyền truy cập cụm EKS tức thì qua IAM/Terraform, an toàn và không bao giờ bị conflict. |

---

## 4. Cách Dùng Thực Tế trong Môi Trường Production

### 1. Cấu Trúc Module EKS Tái Sử Dụng Chuẩn Doanh Nghiệp
```text
modules/eks/
├── main.tf              # Khai báo aws_eks_cluster với full logging & KMS
├── node_group.tf        # aws_eks_node_group kết hợp aws_launch_template (IMDSv2)
├── iam.tf               # Phân tách IAM Role cho Cluster vs Node Group (Least Privilege)
├── kms.tf               # KMS Customer Managed Key với key rotation tự động
├── security_groups.tf   # Chaining SG giữa Control Plane và Worker Nodes
├── addons.tf            # Cài đặt core add-ons: vpc-cni, coredns, kube-proxy
├── variables.tf         # Contract biến có regex validation và length validation
├── outputs.tf           # Export endpoint, certificate_authority_data, oidc_provider_arn
└── versions.tf          # Pin version provider (KHÔNG CHỨA block provider)
```

### 2. Các Thiết Lập Bảo Mật Bắt Buộc (Security Checklist)
- **Cluster Logging:**
  ```hcl
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  ```
- **KMS Secret Encryption:**
  ```hcl
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }
  ```
- **Authentication Mode:**
  ```hcl
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = false
  }
  ```
- **Launch Template IMDSv2:**
  ```hcl
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  ```

---

## 5. Bài Học Xương Máu & Điều Cần Lưu Ý (Hard-won Lessons)

### 💀 Horror Story 1: Thảm Họa Corrupt `aws-auth` ConfigMap Gây Lockout Toàn Bộ Team
- **Sự cố:** Một kỹ sư dùng script automation để thêm IAM Role mới cho pipeline CI/CD vào ConfigMap `aws-auth`. Do lỗi parse YAML trong script, toàn bộ nội dung của `mapRoles` bị format sai thụt lề. Ngay lập tức, EKS API Server từ chối xác thực mọi request từ toàn bộ team DevOps, kể cả quản trị viên cao nhất! Cả team mất hơn 4 giờ đồng hồ liên hệ AWS Support để can thiệp.
- **Biện pháp khắc phục vĩnh viễn:** Chuyển dịch toàn bộ quyền sang **EKS Access Entries** (`aws_eks_access_entry`), vứt bỏ hoàn toàn việc chỉnh sửa trực tiếp `aws-auth`.

### 💀 Horror Story 2: Mở Toang API Server Ra Internet (`0.0.0.0/0`) Dẫn Đến Brute-force
- **Sự cố:** Cluster EKS để mặc định `endpoint_public_access = true` và không giới hạn `public_access_cidrs`. Botnet trên Internet liên tục quét và gửi hàng triệu request thăm dò vào cổng 443 của Kubernetes API Server, gây quá tải Control Plane và đẩy chi phí CloudWatch Logs tăng vọt.
- **Khắc phục:** Luôn bật `endpoint_private_access = true`. Nếu cần truy cập công khai, phải giới hạn `public_access_cidrs = ["x.x.x.x/32"]` (chỉ cho phép dải IP của VPN công ty hoặc IP tĩnh của bastion host).

### 💀 Horror Story 3: Lỗi Mất Pod Network Do Cạn Kiệt IP Trong Private Subnet (VPC CNI Trap)
- **Sự cố:** Đội ngũ tạo 2 Private Subnets với dải mạng hẹp `/24` (chỉ có ~250 IP khả dụng mỗi subnet). Khi triển khai EKS với AWS VPC CNI, mỗi Worker Node EC2 gắn nhiều ENI và chiếm dụng trước một lượng lớn secondary IPs (warm IP target) cho các Pods. Khi số lượng Pod tăng lên trong chiến dịch marketing, Subnet cạn kiệt IP hoàn toàn. Hàng loạt Pod mới rơi vào trạng thái `FailedCreatePodSandBox: no IP addresses available in subnet`.
- **Khắc phục:** Khi thiết kế VPC cho EKS, dải Private Subnet tối thiểu phải là `/20` hoặc `/19` (4,000 - 8,000 IPs) để đáp ứng cơ chế cấp phát IP của AWS VPC CNI.
