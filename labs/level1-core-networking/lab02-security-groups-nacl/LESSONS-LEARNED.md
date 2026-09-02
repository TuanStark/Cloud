# 📘 CẨM NANG THỰC CHIẾN: SECURITY GROUPS VS NACLS & ZERO-TRUST NETWORK
> **Lab 02:** Security Groups vs Network ACLs (NACLs) & Packet Flow  
> **Cấu trúc chuẩn 5 phần:**  
> 1. Service / Khái niệm ➔ 2. **Định nghĩa kỹ thuật chuẩn (Formal Definition)** ➔ 3. **Giải thích dễ hiểu / Ẩn dụ** ➔ 4. **Cách dùng thực tế (Production)** ➔ 5. **Bài học xương máu & Lưu ý**  

---

## 🛡️ 1. SECURITY GROUPS (STATEFUL VIRTUAL FIREWALL)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Security Group (SG)** là một tường lửa ảo hoạt động theo cơ chế **Stateful (Theo dõi trạng thái phiên - Connection Tracking)** ở tầng **Layer 4 (Transport Layer - TCP/UDP/ICMP)** của mô hình OSI.
* SG được gắn trực tiếp vào từng **Giao diện mạng đàn hồi (Elastic Network Interface - ENI)** của tài nguyên (EC2, RDS, ALB, Lambda VPC).
* **Nguyên tắc hoạt động:** Áp dụng mô hình **Implicit Deny (Mặc định chặn tất cả)**. Chỉ hỗ trợ các quy tắc **ALLOW**. Khi một kết nối Inbound được cho phép, luồng Outbound phản hồi tương ứng sẽ **tự động được phép lưu thông** bất kể cấu hình Outbound rules.

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* SG giống như **Cửa khóa thông minh của từng căn hộ riêng lẻ**:
  * Mặc định cửa khóa chặt, chỉ ai có trong danh sách khách mời mới được vào.
  * Khi bạn đã chủ động mở cửa cho khách vào nhà, khách nói chuyện xong thì **tự do bước ra về**, không cần phải xin phép thêm lần nữa (Stateful).

### 🛠️ Cách dùng trong thực tế (Security Group Chaining):
* **Nguyên tắc Zero-Trust:** Tuyệt đối không mở port DB/Backend theo dải IP CIDR tĩnh.
* Cho phép SG này làm **Source** của SG khác:
  ```hcl
  # Backend SG chỉ nhận traffic từ ALB SG
  security_groups = [aws_security_group.alb_sg.id]
  # Database SG chỉ nhận traffic từ Backend SG
  security_groups = [aws_security_group.backend_sg.id]
  ```

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Giới hạn Connection Tracking:** AWS EC2 có giới hạn số lượng phiên kết nối đồng thời được track trong bảng conntrack table. Nếu bị DDoS hàng triệu kết nối, conntrack table bị tràn dẫn đến drop gói tin hợp lệ.
2. **Không hỗ trợ quy tắc DENY:** Bạn không thể dùng SG để chặn một IP cụ thể (ví dụ muốn chặn IP `1.2.3.4` thì SG không làm được, bắt buộc phải dùng NACL hoặc AWS WAF).

---

## 🚦 2. NETWORK ACL (STATELESS SUBNET FIREWALL)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Network Access Control List (NACL)** là một lớp tường lửa ảo hoạt động theo cơ chế **Stateless (Không theo dõi trạng thái phiên)** tại ranh giới của toàn bộ **Subnet**.
* NACL kiểm tra độc lập từng gói tin đi vào (Inbound) và đi ra (Outbound) dựa trên bảng quy tắc có đánh số thứ tự ưu tiên (**Rule Number evaluation từ thấp đến cao: 1 đến 32766, kết thúc bằng `*` Default Deny**).
* Hỗ trợ cả 2 hành động: **ALLOW** và **DENY**.

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* NACL giống như **Trạm kiểm soát an ninh tại cổng làng / barie khu phố**:
  * Kiểm tra giấy tờ từng người một khi bước qua cổng làng.
  * Anh bảo vệ ở đây **bị chứng mất trí nhớ ngắn hạn (Stateless)**: Khi bạn đi qua cổng làng vào trong, anh ta kiểm tra. Nhưng khi bạn quay trở ra, anh ta coi bạn như người hoàn toàn mới và bắt kiểm tra lại từ đầu.

### 🛠️ Cách dùng trong thực tế:
* Trong 95% trường hợp: Để NACL mặc định (**Allow All**) để tránh phức tạp hóa việc quản trị mạng.
* **Chỉ dùng NACL cho mục đích khẩn cấp (Emergency Incident Response):**
  * Khi phát hiện IP của botnet / hacker đang tấn công Brute-force hoặc DDoS: Tạo ngay Rule số nhỏ (ví dụ `Rule 50 DENY hacker-ip/32`) để chặn đứng gói tin ngay từ cửa ngõ Subnet trước khi nó chạm tới server.

### 🩸 Bài học xương máu & Điều cần lưu ý:
1. **Cạm bẫy Ephemeral Ports (1024–65535):** Vì Stateless, nếu mở Inbound Port 80/443 mà quên mở Outbound Ephemeral Ports `1024-65535`, gói tin phản hồi về client sẽ bị drop 100% $\rightarrow$ Web bị treo.
2. **Thứ tự Rule (Rule Number Order):** Rule số 50 `DENY 1.2.3.4` đặt trước Rule 100 `ALLOW 0.0.0.0/0` thì IP `1.2.3.4` bị chặn. Nhưng nếu lỡ tay đặt là Rule 150 `DENY 1.2.3.4` thì IP đó vẫn vào được vì Rule 100 đã khớp trước!

---

## 🔄 3. EPHEMERAL PORTS (CỔNG TẠM THỜI 1024–65535)

### 📐 Định nghĩa kỹ thuật chuẩn (Formal Definition):
* **Ephemeral Port** (Cổng tạm thời theo chuẩn RFC 6056 / IANA) là dải cổng TCP/UDP ngắn hạn được hệ điều hành của máy gửi (Client OS) tự động cấp phát ngẫu nhiên từ ngăn xếp mạng (Network Stack) để làm **Source Port** khi khởi tạo phiên kết nối tới máy chủ đích.
* **Dải cổng theo tiêu chuẩn:**
  * IANA Standard: `49152 – 65535`
  * Linux Kernel (`/proc/sys/net/ipv4/ip_local_port_range`): `32768 – 60999`
  * Windows Server: `49152 – 65535`
  * Quy ước chung trên AWS NACL: Mở toàn dải `1024 – 65535`.

### 💡 Giải thích dễ hiểu (Ẩn dụ đời thường):
* Khi bạn gọi điện tới Tổng đài hỗ trợ (Port 1900 - Cố định), máy điện thoại của bạn sẽ dùng một số máy nhánh ngẫu nhiên tạm thời (ví dụ máy nhánh 54321). Khi tổng đài trả lời, họ phải gọi lại đúng số máy nhánh 54321 đó.

---

## ⚔️ BẢNG TỔNG KẾT SO SÁNH TOÀN DIỆN

| Tiêu chí | Security Group (SG) | Network ACL (NACL) |
| :--- | :--- | :--- |
| **Tầng bảo vệ** | Từng Card mạng ảo (ENI / Instance) | Toàn bộ ranh giới Subnet |
| **Trạng thái (State)** | **Stateful** (Tự động mở chiều về) | **Stateless** (Phải mở cả 2 chiều vào/ra) |
| **Hành vi Rule** | Chỉ có **ALLOW** (Mặc định Deny All) | Có cả **ALLOW** và **DENY** |
| **Thứ tự thực thi** | Toàn bộ rule được đánh giá đồng thời | Đánh giá tuần tự theo **Rule Number** (từ nhỏ đến lớn) |
| **Phạm vi áp dụng** | Kiểm soát traffic Microservices, App $\leftrightarrow$ DB | Chặn IP độc hại, Blacklist dải mạng tấn công |
| **Ephemeral Ports** | Không cần quan tâm (Stateful tự xử lý) | **Bắt buộc phải mở** ở chiều phản hồi |
