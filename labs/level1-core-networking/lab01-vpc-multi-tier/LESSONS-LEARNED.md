# 📘 CẨM NANG THỰC CHIẾN: KIẾN TRÚC MẠNG CLOUD 3-TIER
> **Lab 01:** AWS VPC Multi-Tier Architecture  
> **Cấu trúc chuẩn 5 phần:**  
> 1. Service / Khái niệm ➔ 2. **Định nghĩa kỹ thuật chuẩn (Formal Definition)** ➔ 3. **Giải thích dễ hiểu / Ẩn dụ** ➔ 4. **Cách dùng thực tế (Production)** ➔ 5. **Bài học xương máu & Lưu ý**  

---

## 🌐 1. AWS VPC (Virtual Private Cloud) & CIDR BLOCK

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **AWS VPC** là một mạng riêng ảo được cô lập theo mô hình **Mạng điều khiển bằng phần mềm (Software-Defined Networking - SDN)** trên hạ tầng đám mây toàn cầu của AWS.
* **CIDR (Classless Inter-Domain Routing - RFC 4632):** Phương pháp phân bổ địa chỉ IP và định tuyến linh hoạt thay thế cho kiến trúc phân lớp truyền thống (Class A, B, C). Dải IP của VPC hoạt động trên các dải IP Private chuẩn **RFC 1918** (ví dụ: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`).

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* **VPC** giống như một **khu đô thị khép kín có tường bao quanh** được cấp riêng cho công ty bạn.
* **CIDR** giống như **tổng diện tích đất của cả khu đô thị** (ví dụ: `/16` tương đương cấp cho bạn 65,536 lô đất để xây nhà).

### 🛠️ Cách dùng trong thực tế:
* Luôn khởi tạo VPC với dải CIDR chuẩn `/16` (ví dụ: `10.0.0.0/16` hoặc `172.16.0.0/16`).
* Bắt buộc bật 2 cờ phân giải DNS:
  * `enable_dns_support = true`: Kích hoạt dịch vụ DNS Resolver nội bộ của AWS (`AmazonProvidedDNS` tại địa chỉ `.2`).
  * `enable_dns_hostnames = true`: Tự động gán Public/Private DNS hostname tương ứng cho các máy chủ EC2/RDS.

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Thảm họa cạn kiệt IP (CIDR Exhaustion):** Không bao giờ tạo VPC nhỏ như `/24` (chỉ có 256 IP). Khi triển khai Kubernetes (EKS), mỗi Pod ngốn 1 IP riêng, subnet sẽ cạn IP trong vài tuần và bạn sẽ phải đập toàn bộ hạ tầng đi xây lại từ đầu.
2. **Không thể đổi CIDR chính:** Sau khi đã khởi tạo VPC, bạn **KHÔNG THỂ** sửa đổi dải CIDR gốc.
3. **Tránh trùng lặp IP:** Khi thiết kế, phải đối chiếu với mạng On-Premises của công ty hoặc các VPC khác để đảm bảo không bị trùng IP khi sau này làm **VPC Peering**, **AWS Transit Gateway** hoặc **AWS Direct Connect**.

---

## 🚪 2. INTERNET GATEWAY (IGW)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Internet Gateway (IGW)** là một thành phần phần mềm phân tán, có tính sẵn sàng cao và khả năng mở rộng ngang tự động (**Horizontally scaled, redundant, highly available VPC component**) của AWS.
* Nó đóng vai trò là đích đến (Target) trong Route Table để thực hiện kỹ thuật **1-to-1 NAT** giữa địa chỉ IPv4 Private và IPv4 Public của tài nguyên trong VPC khi giao tiếp với mạng Internet toàn cầu.

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* **IGW** giống như **Cổng chính của khu đô thị**, nối đường nội bộ trong làng ra đường quốc lộ lớn (Internet). 
* Cổng này mở cho xe cộ đi lại tự do **2 chiều (Inbound & Outbound)** nếu có giấy phép hợp lệ.

### 🛠️ Cách dùng trong thực tế:
* Mỗi VPC chỉ gắn duy nhất **1 Internet Gateway**.
* Dịch vụ hoàn toàn miễn phí, không giới hạn băng thông và không có điểm nghẽn (No single point of failure).

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **IGW không tự động giúp server ra Internet:** Server muốn kết nối Internet phải thỏa mãn đủ 3 điều kiện đồng thời:
   - Subnet có Route Table trỏ `0.0.0.0/0` về IGW.
   - Server phải có Public IPv4 (hoặc Elastic IP).
   - Security Group và NACL cho phép lưu lượng đi qua.
2. **Nguy cơ bảo mật:** Tuyệt đối không gắn Internet Gateway vào các Route Table của Subnet chứa Database hoặc Backend xử lý lõi.

---

## 🏘️ 3. SUBNETS (PUBLIC, PRIVATE APP, ISOLATED DB) & MULTI-AZ

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Subnet** là một phân đoạn logic (Logical Subdivision) thuộc dải địa chỉ IP của VPC, và **bắt buộc phải nằm trọn vẹn trong một Availability Zone (AZ) duy nhất**.
  * **Public Subnet:** Subnet có bảng định tuyến (Route Table) chứa route trực tiếp tới Internet Gateway (`0.0.0.0/0 -> igw-xxx`).
  * **Private Subnet:** Subnet có bảng định tuyến không trỏ tới IGW (thường trỏ tới NAT Gateway hoặc hoàn toàn không có route mặc định ra ngoài).
* **Multi-AZ Architecture:** Kiến trúc phân tán tài nguyên trên ít nhất 2 Availability Zones độc lập về điện, làm mát và mạng vật lý để đảm bảo chỉ số **RPO / RTO** và tính sẵn sàng cao (High Availability).

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* Subnet giống như **từng phân khu chức năng** trong đô thị:
  * **Public Subnet:** Khu phố thương mại mặt tiền (cho khách vãng lai ra vào tự do).
  * **Private App Subnet:** Khu chung cư cư dân cao cấp (chỉ cư dân có thẻ mới vào được, người trong đi ra ngoài được).
  * **Isolated DB Subnet:** Hầm giữ két sắt bí mật (hoàn toàn biệt lập, không có cửa mở ra đường cái).

### 🛠️ Cách dùng trong thực tế (Mô hình 3-Tier Enterprise):
* **Public Subnets (`10.0.1.0/24`, `10.0.2.0/24`):** Đặt ALB, NAT Gateway, Bastion. Bật `map_public_ip_on_launch = true`.
* **Private App Subnets (`10.0.11.0/24`, `10.0.12.0/24`):** Đặt Backend App (NestJS/NodeJS), EKS Worker Nodes. Đi Internet 1 chiều qua NAT Gateway.
* **Database Subnets (`10.0.21.0/24`, `10.0.22.0/24`):** Đặt RDS PostgreSQL Master/Replica, Redis. Tắt hoàn toàn Public IP, không có Internet.

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Bẫy 5 IP bí ẩn của AWS:** Mọi subnet AWS đều bị trừ mất 5 IP đầu và cuối (`.0` Network, `.1` VPC Router, `.2` DNS, `.3` Reserved, `.255` Broadcast). Subnet `/28` (16 IP) chỉ còn thực dùng được **11 IP**.
2. **Kích thước Subnet cho EKS:** Subnet cho Private App nên cấp tối thiểu `/20` (4,091 IP) để tránh nghẽn khi số lượng Pods tăng cao.
3. **Tai nạn Public IP trên Database:** Nếu vô tình để `map_public_ip_on_launch = true` trên Subnet DB, một sơ suất nhỏ trong Security Group sẽ khiến toàn bộ dữ liệu công ty bị scan và dính Ransomware.

---

## 🚦 4. ROUTE TABLES & ASSOCIATIONS

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Route Table** là một tập hợp các quy tắc định tuyến (Route Rules) bao gồm **Destination CIDR** (dải IP đích) và **Target** (nơi chuyển tiếp gói tin tiếp theo - Next-hop), quyết định hướng đi của các gói tin IP (Layer 3 OSI) rời khỏi Subnet.
* Router của AWS hoạt động dựa trên thuật toán **Longest Prefix Match (Khớp tiền tố dài nhất)** để ưu tiên chọn đường đi có dải mạng cụ thể nhất.

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* Route Table là **bản đồ chỉ đường và biển báo giao thông** đặt tại ngã tư của mỗi phân khu, chỉ dẫn gói tin biết phải rẽ theo lối nào để đến đúng địa chỉ.

### 🛠️ Cách dùng trong thực tế:
* **Public Route Table:** Có dòng `0.0.0.0/0 -> igw-xxxx` (Mọi lưu lượng ra ngoài thế giới thì đẩy ra Cổng chính IGW). Gắn vào Public Subnets.
* **Private App Route Table:** Có dòng `0.0.0.0/0 -> nat-xxxx` (Mọi lưu lượng ra ngoài thì đẩy sang trạm NAT trung chuyển). Gắn vào Private App Subnets.
* **Database Route Table:** **KHÔNG CÓ DÒNG `0.0.0.0/0`**, chỉ có dòng ngầm định `10.0.0.0/16 -> local`. Gắn vào Database Subnets.

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Nguyên tắc Longest Prefix Match:** Nếu gọi IP `10.0.21.5` (Database), Router thấy nó khớp với `10.0.0.0/16` (nội bộ) nên sẽ đi thẳng nội bộ với độ trễ cực thấp (<1ms), không bao giờ bị đẩy nhầm ra ngoài `0.0.0.0/0`.
2. **Mỗi Subnet chỉ gắn duy nhất 1 Route Table tại 1 thời điểm:** Nếu không cấu hình association rõ ràng, AWS sẽ tự động gán Subnet vào Main Route Table mặc định (Rất dễ gây rò rỉ bảo mật ngoài ý muốn).

---

## 🔄 5. NAT GATEWAY & ELASTIC IP (EIP)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **NAT Gateway** là dịch vụ biên dịch địa chỉ mạng có quản lý (**Managed Network Address Port Translation - NAPT / Masquerading - RFC 3022**) của AWS.
* Nó cho phép các instance trong Private Subnet thiết lập kết nối ra ngoài Internet (Egress-only) thông qua cơ chế **Stateful Connection Tracking** (lưu lại bảng trạng thái phiên làm việc), đồng thời chặn hoàn toàn các kết nối chủ động từ Internet vào bên trong.
* **Elastic IP (EIP):** Địa chỉ IPv4 Public tĩnh, cố định được cấp phát cho tài khoản AWS để gán vào NAT Gateway hoặc EC2.

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* **NAT Gateway** giống như **người shipper đại diện**:
  * Khi người trong chung cư (Private Subnet) muốn mua hàng trên mạng, shipper cầm đơn đi ra ngoài mua hộ mang về.
  * Người bán hàng ngoài Internet chỉ nhìn thấy mặt của shipper (Elastic IP), hoàn toàn **không biết nhà riêng** của người mua.

### 🛠️ Cách dùng trong thực tế:
* NAT Gateway **BẮT BUỘC PHẢI ĐẶT Ở PUBLIC SUBNET** và gắn kèm 1 Elastic IP.
* Khi đối tác thanh toán (VNPAY, PayOS, Stripe) yêu cầu cung cấp IP tĩnh để đưa vào Whitelist, bạn cung cấp chính là **Elastic IP của NAT Gateway**.

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Cú sốc hóa đơn NAT Gateway ($0.045/GB):** Không bao giờ để traffic đọc/ghi S3 hoặc DynamoDB đi qua NAT Gateway. Bắt buộc phải tạo **VPC Gateway Endpoints** (miễn phí 100%) để tiết kiệm hàng nghìn USD mỗi tháng.
2. **SPOF trên Production:**
   * *Môi trường Dev:* Dùng **1 NAT Gateway** ở AZ-a để tiết kiệm (~$32/tháng).
   * *Môi trường Production:* Bắt buộc **Multi-NAT GW (Mỗi AZ 1 con NAT riêng)**. Nếu dùng chung 1 NAT GW, khi AZ đó sập mạng thì toàn bộ các AZ còn lại cũng sẽ mất Internet.
3. **Chi phí hoạt động:** NAT Gateway tính phí theo giờ hoạt động ($0.045/giờ $\approx$ $32/tháng) cộng phí dung lượng xử lý dữ liệu ($0.045/GB). Dùng xong bài lab phải nhớ `terraform destroy` để tránh phát sinh chi phí.
