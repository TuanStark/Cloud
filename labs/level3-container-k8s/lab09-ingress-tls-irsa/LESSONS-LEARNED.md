# 📚 BÀI HỌC KINH NGHIỆM: LEVEL 3 - LAB 09 (KUBERNETES INGRESS, TLS TERMINATION & IRSA)

---

## 1. Dịch vụ & Khái niệm Cốt lõi (Core Concepts)

Trong môi trường Kubernetes cấp doanh nghiệp (AWS EKS), một ứng dụng muốn vận hành an toàn và tin cậy phải giải quyết triệt để 2 chiều giao tiếp:
- **Chiều Ingress (Bên ngoài đi vào Pod):** Làm thế nào để đón hàng triệu request HTTPS từ Internet vào Pod chạy trong Private Subnet với độ trễ thấp nhất, bảo toàn IP thực của client, và tự động ép buộc mã hóa TLS 1.3?
- **Chiều Egress & Identity (Pod gọi ra dịch vụ AWS Cloud):** Làm thế nào để Pod ghi file lên S3, đọc message từ SQS, hoặc truy vấn DynamoDB mà **TUYỆT ĐỐI KHÔNG CẦN ACCESS KEY / SECRET KEY** và **KHÔNG LẠM DỤNG QUYỀN CỦA WORKER NODE**?

Bài lab này đúc kết toàn diện 4 trụ cột kỹ thuật đỉnh cao:
1. **AWS Load Balancer Controller (ALB Ingress):** Điều khiển Application Load Balancer cấp phát động từ manifest Kubernetes Ingress.
2. **Target-Type IP (VPC CNI Superpower):** Chuyển trực tiếp traffic từ ALB vào IP riêng của Pod, loại bỏ NodePort và kube-proxy.
3. **Bắt Buộc Mã Hóa TLS 1.3 & SSL Redirect:** Ép buộc chuyển hướng HTTP 301 sang HTTPS và áp dụng bộ ciphers bảo mật nhất đáp ứng chuẩn thanh toán PCI-DSS.
4. **IRSA (IAM Roles for Service Accounts):** Chuẩn mực bảo mật danh tính Pod thông qua OpenID Connect (OIDC) Federation và AWS STS.

---

## 2. Định nghĩa Kỹ thuật Chuẩn (Formal Definition)

### A. Ingress Target-Type: `ip` vs `instance`
- **Chế độ `instance` (Truyền thống / Hạn chế):**
  - Traffic từ Internet -> ALB -> NodePort của EC2 Worker Node ngẫu nhiên -> `kube-proxy` (iptables/IPVS) trên Node đó thực hiện DNAT chuyển tiếp gói tin sang Pod thực sự trên Node khác.
  - **Hậu quả:** Mất Client Source IP (bị biến thành IP của Node), phát sinh thêm 1 network hop (tăng độ trễ 5 - 15ms), gây nghẽn bảng iptables khi scale lớn.
- **Chế độ `ip` (Chuẩn Enterprise với AWS VPC CNI):**
  - Nhờ AWS VPC CNI, mỗi Pod sở hữu một địa chỉ IP thực nội bộ trong dải VPC Subnet.
  - ALB đăng ký trực tiếp địa chỉ IP của từng Pod vào ALB Target Group.
  - Gói tin từ ALB bắn thẳng vào card mạng ENI của Pod, bỏ qua hoàn toàn NodePort và `kube-proxy`. Giữ nguyên 100% Client Source IP, tối ưu hóa tối đa throughput.

### B. Cơ Chế IRSA (IAM Roles for Service Accounts)
- **Định nghĩa:** Cơ chế ủy quyền liên kết danh tính (Federated Identity) giữa Kubernetes ServiceAccount và AWS IAM Role mà không cần bất kỳ long-lived credentials nào.
- **Quy trình hoạt động 5 bước:**
  1. **OIDC Discovery:** Cụm EKS sở hữu một OIDC Identity Provider URL công khai chứa public keys để AWS STS kiểm tra chữ ký số.
  2. **Token Injection:** EKS Pod Identity Webhook tự động gắn Projected Service Account Token (JWT) vào Pod tại `/var/run/secrets/eks.amazonaws.com/serviceaccount/token` và inject biến môi trường `AWS_ROLE_ARN`, `AWS_WEB_IDENTITY_TOKEN_FILE`.
  3. **AssumeRole Request:** AWS SDK bên trong ứng dụng đọc token JWT và gọi API `sts:AssumeRoleWithWebIdentity`.
  4. **Trust Validation:** AWS STS xác thực chữ ký của JWT với EKS OIDC Issuer, kiểm tra 2 điều kiện bắt buộc trong IAM Trust Policy:
     - `"${OIDC_PROVIDER}:sub" == "system:serviceaccount:<namespace>:<serviceaccount-name>"`
     - `"${OIDC_PROVIDER}:aud" == "sts.amazonaws.com"`
  5. **Temporary Credentials:** STS cấp Temporary Credentials (AccessKey, SecretKey, SessionToken) có thời hạn 15 - 60 phút để Pod giao tiếp với AWS S3/KMS/RDS.

### C. TLS Termination & Modern SSL Security Policy
- **Định nghĩa:** Toàn bộ quá trình bắt tay SSL (SSL Handshake), trao đổi khóa mã hóa và giải mã HTTPS diễn ra tập trung tại tầng Application Load Balancer (ALB). Giao tiếp từ ALB vào Pods bên trong Private Subnet đi qua mạng nội bộ AWS an toàn.
- **SSL Policy `ELBSecurityPolicy-TLS13-1-2-2021-06`:** Chỉ hỗ trợ TLS 1.2 và TLS 1.3 với các bộ ciphers hiện đại (ECDHE-RSA-AES128-GCM-SHA256, TLS_AES_128_GCM_SHA256...). Chặn đứng hoàn toàn các cuộc tấn công BEAST, POODLE, HEARTBLEED từ các chuẩn SSLv3, TLS 1.0, 1.1 cũ.

---

## 3. Giải thích Dễ hiểu & Ẩn dụ Thực tế (Metaphors)

| Khái niệm | Ẩn dụ Đời sống | Ý nghĩa Thực tế trong Vận hành |
| :--- | :--- | :--- |
| **Target-Type `instance`** | Khách đáp máy bay đến cổng sân bay, phải bắt taxi đi lòng vòng qua 3 bến xe trung gian rồi mới được trung chuyển về khách sạn. | Đi qua NodePort và iptables, tăng độ trễ mạng, tốn CPU của worker node để route gói tin hộ pod khác. |
| **Target-Type `ip`** | Trực thăng đón khách từ sân bay bay thẳng đáp xuống nóc khách sạn. | ALB forward thẳng vào IP riêng của Pod, không qua trung gian, tốc độ nhanh nhất. |
| **Gán quyền cho Node Role** | Đưa chìa khóa Master Key mở được mọi két sắt trong cả tòa nhà cho người bảo vệ gác cổng. | Cực kỳ nguy hiểm. Một Pod bán hàng bị hack có thể dùng quyền của Node để xóa sạch database hay S3 của công ty. |
| **Cơ chế IRSA** | Lễ tân chỉ cấp thẻ từ quét thang máy lên đúng tầng 5 và chỉ mở đúng phòng 502 trong vòng 30 phút. | Pod chỉ được cấp đúng quyền tối thiểu (Least Privilege), hết hạn tự động hủy, các Pod khác chung Node không bao giờ dùng ké được. |
| **SSL Redirect (HTTP -> HTTPS)** | Trạm kiểm soát an ninh tự động từ chối và hướng dẫn người đi bộ sang làn có cổng soi chiếu an ninh nghiêm ngặt. | Ngăn chặn người dùng vô tình gửi password/token ở dạng plain-text qua cổng 80 HTTP. |

---

## 4. Cách Dùng Thực Tế trong Môi Trường Production

### 1. Mẫu Cấu Hình IAM Trust Policy Chuẩn Cho IRSA (`irsa.tf`)
```hcl
data "aws_iam_policy_document" "irsa_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    # BẮT BUỘC: Giới hạn chính xác namespace và tên ServiceAccount
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    # BẮT BUỘC: Audience phải là sts.amazonaws.com
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}
```

### 2. Mẫu Ingress Đạt Chuẩn Ngân Hàng / FinTech (`05-ingress.yaml`)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: order-app-ingress
  namespace: order-app
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
spec:
  tls:
    - hosts:
        - order.starkcloud.io
      secretName: order-tls-secret
  rules:
    - host: order.starkcloud.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: order-app-service
                port:
                  number: 80
```

### 3. Kịch Bản Kiểm Thử An Ninh Hai Chiều (Dual-Verification Test)
- **Test 1: Pod Authorized (order-app-sa):**
  ```bash
  kubectl apply -f scripts/01-test-authorized-pod.yaml
  kubectl logs test-irsa-authorized -n order-app
  # Kết quả: STS trả về assumed-role/order-irsa-dev và aws s3 ls thành công!
  ```
- **Test 2: Pod Unauthorized (default SA):**
  ```bash
  kubectl apply -f scripts/02-test-unauthorized-pod.yaml
  kubectl logs test-irsa-unauthorized -n order-app
  # Kết quả: Bị chặn đứng với lỗi "Unable to locate credentials" hoặc "AccessDenied"!
  ```

---

## 5. Bài Học Xương Máu & Điều Cần Lưu Ý (Hard-won Lessons)

### 💀 Horror Story 1: Thảm Họa Đánh Cắp Toàn Bộ Dữ Liệu S3 Qua EC2 Instance Profile
- **Sự cố:** Một công ty thương mại điện tử gán quyền `AmazonS3FullAccess` trực tiếp vào IAM Role của Worker Node EC2 để thuận tiện cho các ứng dụng đọc/ghi ảnh sản phẩm. Một Pod blog Wordpress chạy chung Node bị dính lỗ hổng Remote Code Execution (RCE). Kẻ tấn công mở reverse shell, thực thi lệnh `curl http://169.254.169.254/latest/meta-data/iam/security-credentials/` để lấy cắp IAM Role của Node. Với quyền FullAccess đó, kẻ tấn công đã tải toàn bộ cơ sở dữ liệu khách hàng và tống tiền công ty 200,000 USD!
- **Bài học khắc phục:** Tuyệt đối không cấp quyền nghiệp vụ cho Node IAM Role. Mọi dịch vụ đều phải dùng **IRSA**.

### 💀 Horror Story 2: Lỗi Mất Source IP Làm Tê Liệt Hệ Thống Chống DDoS / WAF
- **Sự cố:** Hệ thống dùng Ingress với `target-type: instance`. Toàn bộ gói tin từ ALB đi vào Pod qua NodePort khiến IP nguồn của khách hàng bị đổi thành IP nội bộ của Worker Node (`10.0.x.x`). Bộ lọc rate-limit và AWS WAF tưởng nhầm hàng ngàn người dùng là cùng một IP nội bộ, dẫn đến việc block nhầm toàn bộ người dùng thật và tê liệt doanh thu cả ngày.
- **Khắc phục:** Chuyển sang `target-type: ip`. ALB forward trực tiếp vào Pod ENI, bảo toàn 100% Client IP gốc.

### 💀 Horror Story 3: Lỗi Lỗ Hổng Plaintext HTTP Khiến Rò Rỉ JWT Token
- **Sự cố:** Ingress chỉ mở cổng 80 và không cấu hình SSL Redirect. Nhiều người dùng truy cập qua mạng Wifi công cộng bằng đường link `http://`. Kẻ tấn công dùng công cụ sniffing bắt trọn toàn bộ Bearer Token của người dùng gửi qua HTTP header, mạo danh chiếm đoạt hàng trăm tài khoản VIP.
- **Khắc phục:** Luôn khai báo `alb.ingress.kubernetes.io/ssl-redirect: '443'` để mọi request HTTP đều bị chuyển hướng sang HTTPS mã hóa trước khi xử lý logic.
