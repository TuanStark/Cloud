# 📜 Architecture Decision Record (ADR-001)
## Đề Tài: Kiến Trúc Hệ Thống E-Commerce / Fintech Chịu Tải Cao (Flash Sale 10,000 RPS)

- **Trạng thái:** `ACCEPTED` (Đã phê duyệt)
- **Tác giả:** Lê Công Tuấn (Lead SRE / DevSecOps Engineer) & Principal SRE Mentor
- **Ngày lập:** 2026-09-12
- **Dự án:** High-Throughput E-Commerce Core Engine

---

## 1. Bối Cảnh Bài Toán Kinh Doanh (Context & Business Requirements)

Doanh nghiệp chuẩn bị tổ chức chiến dịch **Flash Sale Mega-Day (11.11 / Black Friday)** với kỳ vọng:
1. **Lưu lượng truy cập cực đại:** Tăng đột biến từ 200 RPS ngày thường lên **10,000 Requests/Second (RPS)** trong vòng 60 giây đầu tiên mở bán.
2. **Loại giao dịch:**
   - 80% lưu lượng là **Đọc thông tin sản phẩm và kiểm tra tồn kho** (Read-heavy).
   - 20% lưu lượng là **Đặt hàng và thanh toán giữ chỗ** (Write-heavy, giao dịch tài chính nhạy cảm).
3. **Cam kết SLA / SLO:**
   - Availability: $\ge 99.95\%$ (Thời gian chết tối đa không quá 21.6 phút/tháng).
   - P99 Latency: $\le 150\text{ms}$ cho API Đọc; $\le 300\text{ms}$ cho API Ghi.
   - **RPO = 0 (Recovery Point Objective):** Tuyệt đối không được phép mất mát bất kỳ bản ghi đặt hàng nào đã xác nhận thành công.

---

## 2. Bài Toán Tính Toán Năng Lực Hạ Tầng (Capacity Planning Math)

Là một Senior SRE, không bao giờ đoán mò kích thước server mà phải tính toán dựa trên định luật vật lý và toán học:

### A. Tải Đọc (Read Traffic - 8,000 RPS):
- Kích thước trung bình của payload chi tiết sản phẩm: $\approx 2\text{ KB}$.
- Băng thông mạng yêu cầu: $8,000 \times 2\text{ KB} = 16,000\text{ KB/s} \approx 16\text{ MB/s} = 128\text{ Mbps}$.
- **Vấn đề:** Nếu 8,000 RPS này đánh trực tiếp vào PostgreSQL:
  - Một instance Postgres tiêu chuẩn thường chỉ chịu được tối đa 1,000 – 2,000 QPS đơn giản. 8,000 queries phức tạp kèm JOIN bảng sẽ làm CPU 100% và cạn kiệt Connection Pool trong 3 giây!
  - **Giải pháp bắt buộc:** Sử dụng **Redis In-Memory Cache** (Redis xử lý dễ dàng 50,000 - 100,000 QPS trên single thread) kết hợp kỹ thuật **Cache Aside** và **Mutex Lock** chống Cache Stampede.

### B. Tải Ghi (Write Traffic - 2,000 RPS):
- Mỗi đơn hàng yêu cầu: Trừ tồn kho + Tạo đơn hàng + Sinh mã thanh toán.
- Nếu ghi đồng bộ (Synchronous ACID Transaction) vào DB:
  - Mỗi transaction mất trung bình $15\text{ms}$ disk I/O.
  - Tối đa 1 kết nối xử lý được: $1,000\text{ms} / 15\text{ms} \approx 66\text{ TPS}$.
  - Để chịu 2,000 TPS đồng bộ, Postgres cần: $2,000 / 66 \approx 30$ concurrent active transactions liên tục ghi vào cùng các hàng (Row Lock contention trên bảng Kho hàng). ➔ Dẫn đến **Lock Deadlocks** và sập toàn diện!
  - **Giải pháp bắt buộc:** Chuyển sang mô hình **Bất đồng bộ Hướng sự kiện (Event-Driven Asynchronous Processing)** qua **Apache Kafka**. API chỉ xác thực và đẩy message vào Kafka trong $3\text{ms}$, Worker phía sau đọc tuần tự để trừ kho an toàn.

---

## 3. Các Phương Án Kiến Trúc Đã Cân Nhắc (Options Evaluated)

### Phương án A: Monolithic Database-Centric Architecture
- *Mô tả:* Mọi API (Auth, Order, Product) gộp chung một app, trỏ thẳng vào một cơ sở dữ liệu PostgreSQL lớn (Scale Up server 64 cores, 256GB RAM).
- *Lý do loại bỏ:*
  - Single Point of Failure (SPOF): DB sập là toàn bộ hệ thống tê liệt.
  - Row Lock Contention: Khi hàng nghìn người cùng mua 1 món hàng hot, DB bị nghẽn ở bước khóa bản ghi (Locking).
  - Chi phí phần cứng cực kỳ đắt đỏ và không co giãn linh hoạt được.

### Phương án B: Microservices Đồng Bộ (Synchronous HTTP/gRPC)
- *Mô tả:* Tách thành các service độc lập (Auth, Order, Inventory, Payment) gọi nhau qua gRPC/HTTP.
- *Lý do loại bỏ:*
  - Cascading Failure: Nếu Payment Service chậm 500ms, Order Service sẽ bị giữ connection, kéo theo NGINX cạn worker, sập toàn bộ dây chuyền.

### Phương án C (CHỌN): 3-Tier Event-Driven Architecture với Read/Write Split & Queue Buffering
- *Mô tả:*
  - **Tier 1 (Gateway & Caching):** NGINX Rate Limiter + Redis Cluster lưu trữ session & thông tin sản phẩm.
  - **Tier 2 (Core Services & Message Bus):** Order Service nhận đơn ➔ Đẩy vào Apache Kafka Topic `order-created` ➔ Trả ngay mã `Order ID` (Pending) cho client trong $< 20\text{ms}$.
  - **Tier 3 (Workers & Database HA):** Order Processor Worker đọc Kafka theo tốc độ tối ưu của Database. Database tách làm **Primary Master (Ghi)** và **Standby Replica (Đọc & Sao lưu đồng bộ)**.

---

## 4. Quyết Định Kỹ Thuật Chi Tiết (Technical Decisions)

| Thành phần | Lựa chọn công nghệ | Rationale (Lý do chọn) |
| :--- | :--- | :--- |
| **API Gateway** | NGINX Reverse Proxy | Quản lý SSL termination, nén gzip, và quan trọng nhất: **Leak Bucket Rate Limiting** (chặn bot spam). |
| **Event Bus** | Apache Kafka | Throughput hàng trăm nghìn msg/sec, bảo đảm thứ tự (Partition key theo `product_id`), khả năng replay dữ liệu khi worker crash. |
| **In-Memory Cache**| Redis v7 | Tốc độ sub-millisecond, hỗ trợ Atomic Operations (`DECRBY`, `SETNX`) để kiểm tra nhanh số lượng tồn kho trước khi vào queue. |
| **Relational DB** | PostgreSQL 16 HA | Hỗ trợ Streaming Replication, độ tin cậy chuẩn ACID. Tách port đọc (Replica) và port ghi (Primary). |
| **Autoscaling** | KEDA (Kubernetes Event-driven) | Scale Pods tự động không chỉ theo CPU mà dựa vào **Kafka Consumer Lag** (Khi hàng đợi tồn $> 500$ messages thì lập tức spawn thêm worker). |
| **Resilience** | Circuit Breaker | Tự động ngắt kết nối đến DB khi tỷ lệ lỗi vượt quá 50% trong 5 giây, trả về fallback response thay vì treo luồng. |

---

## 5. Hậu Quả & Đánh Đổi (Consequences & Trade-offs)

### Điểm mạnh (Pros):
- **Khả năng chịu tải vượt trội:** Hệ thống có thể hấp thụ shock traffic 10,000 RPS mà không làm nghẽn Database nhờ Kafka đóng vai trò đệm giảm xóc (*Shock Absorber*).
- **Trải nghiệm người dùng mượt mà:** Khách hàng nhận được phản hồi đặt hàng ngay lập tức thay vì nhìn biểu tượng quay tròn chờ thanh toán.
- **Tính sẵn sàng cao (HA):** Nếu 1 Worker chết, Kafka giữ message nguyên vẹn, Pod mới mọc lên tiếp tục xử lý mà không mất dữ liệu.

### Đánh đổi (Cons) & Cách Khắc Phục:
- **Tính nhất quán sau cùng (Eventual Consistency):** Khách đặt hàng xong trạng thái sẽ là `PROCESSING`, sau vài giây worker xử lý xong mới chuyển sang `CONFIRMED`.
  - *Khắc phục:* Web UI/Mobile App sử dụng WebSocket hoặc Polling trạng thái đơn hàng.
- **Phức tạp trong vận hành:** Phải giám sát độ trễ replication của Postgres và Consumer Lag của Kafka.
  - *Khắc phục:* Cài đặt Prometheus exporter chuyên dụng cho Kafka và Postgres.
