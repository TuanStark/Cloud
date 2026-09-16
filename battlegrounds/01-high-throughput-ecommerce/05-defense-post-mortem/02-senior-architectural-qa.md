# 🎓 SENIOR SRE & CLOUD ARCHITECT DEFENSE DRILL (10 CÂU HỎI PHẢN BIỆN HÓC BÚA)
## Bộ Câu Hỏi & Lời Giải Bảo Vệ Kiến Trúc Hệ Thống Chịu Tải Cao (2–3+ YoE)
### Battleground 01: High-Throughput E-Commerce Core Engine

Tài liệu này tổng hợp **10 câu hỏi phỏng vấn phản biện kiến trúc chuyên sâu** thường gặp trong các buổi Senior System Design & SRE Defense tại các tập đoàn công nghệ lớn (Shopee, Grab, Momo, AWS).

---

### ❓ CÂU HỎI 1: Tại sao bạn lại chọn kiến trúc Asynchronous Event-Driven với Kafka thay vì ghi trực tiếp xuống PostgreSQL có Connection Pool (PgBouncer)?
> **Lời giải bảo vệ kiến trúc (Senior SRE):**
> - **Điểm nghẽn vật lý của RDBMS:** PostgreSQL sử dụng cơ chế lưu trữ quan hệ với ACID Transaction, MVCC, và Write-Ahead Log (WAL). Mỗi write request đòi hỏi disk sync (fsync), row-level lock và cập nhật B-tree index. Ngay cả khi có PgBouncer, giới hạn throughput ghi của một con Aurora PG instance thông thường chỉ dao động từ **2,000 – 4,000 TPS** trước khi CPU hoặc I/O chực chờ bão hòa.
> - **Shock Absorber (Bộ đệm chịu lực):** Bão Flash Sale 10,000 RPS sẽ làm nổ tung connection pool và gây lock contention nếu ghi trực tiếp. Bằng cách chèn **Apache Kafka** làm hàng đợi đệm ở giữa:
>   1. API Ingestion chỉ mất **`< 15ms`** để append message vào Kafka memory buffer rồi trả về `HTTP 202 Accepted` cho khách hàng.
>   2. Tầng Worker biến luồng tải nhọn (traffic spikes) thành luồng phẳng (constant processing rate), gom thành các đợt **Batch Insert** (50–100 orders/batch) xuống PostgreSQL. Batch insert giảm thiểu số lần round-trip mạng tới 95%, đưa hiệu năng ghi DB từ 2,000 TPS lên hơn 10,000 TPS một cách êm ái.

---

### ❓ CÂU HỎI 2: Trong cơn bão 10,000 RPS, bằng cách nào bạn đảm bảo TUYỆT ĐỐI không xảy ra hiện tượng Bán Âm Kho (Zero Overselling)?
> **Lời giải bảo vệ kiến trúc:**
> - **Vấn đề của các giải pháp truyền thống:**
>   - `SELECT FOR UPDATE` trên SQL: Gây deadlocks và biến hàng chục ngàn kết nối thành hàng đợi tuần tự, khiến latency vọt lên hàng chục giây.
>   - `Distributed Lock (Redlock)`: Tốn ít nhất 2–3 network round-trips để acquire và release lock, không thể đạt được throughput 10,000 RPS.
> - **Giải pháp Atomic Lua Script trên Redis:**
>   - Redis là Single-Threaded Event Loop. Bất kỳ đoạn mã Lua Script nào chạy trong Redis đều có tính **nguyên tử tuyệt đối (Atomic Execution)** — không một command nào khác có thể chen ngang.
>   - Script kiểm tra: Nếu `stock >= requested_qty` thì mới trừ kho, nếu không đủ thì trả về `-2 (Out of Stock)`.
>   - Toàn bộ quá trình kiểm tra và trừ kho diễn ra trong **`< 0.8ms`** ngay trên RAM. Khi chiếc thứ 10,000 được bán ra, tồn kho dừng chính xác ở 0 và mọi request sau đó đều nhận 409 ngay lập tức.

---

### ❓ CÂU HỎI 3: Singleflight Pattern hoạt động ra sao và nó khác gì so với Cache-Aside thông thường?
> **Lời giải bảo vệ kiến trúc:**
> - **Hạn chế của Cache-Aside thông thường (Dogpile Effect):** Khi cache miss xảy ra trên một key hot (ví dụ hàng triệu người cùng F5 xem iPhone khi vừa mở bán), 10,000 requests cùng thấy cache = null và cả 10,000 requests cùng query xuống DB cùng 1 giây.
> - **Cơ chế Singleflight (Request Coalescing):**
>   - Singleflight quản lý một bảng Map các Promise đang thực thi (`in-flight`).
>   - Khi Request 1 gặp cache miss, nó đăng ký một Promise truy vấn DB vào Map.
>   - Khi Request 2 đến Request 1,000 ùa vào trong cùng vài mili-giây đó, chúng thấy key đã có trong Map nên **không gọi DB**, mà chỉ việc `await` chung cái Promise của Request 1.
>   - Khi Request 1 có kết quả từ DB, kết quả lập tức được trả về đồng loạt cho cả 1,000 requests.
>   - Kết quả đo đạc thực tế: **Giảm tải Database tới 98.00%** trong thời gian Redis bị gián đoạn.

---

### ❓ CÂU HỎI 4: Khi Redis hoặc Kafka bị sự cố, Circuit Breaker bảo vệ hệ thống như thế nào để tránh Cascading Failure?
> **Lời giải bảo vệ kiến trúc:**
> - **Nguy cơ Cascading Failure:** Nếu Redis bị sập mạng, mỗi request từ client sẽ bị treo 5 giây chờ TCP timeout. Khi 1,000 request/giây bị treo, chỉ trong 2 giây toàn bộ Node.js Event Loop và HTTP Connection sockets bị cạn kiệt, kéo sập luôn cả các API khác đang chạy chung Pod.
> - **Cơ chế Circuit Breaker:**
>   - Triển khai Finite State Machine 3 trạng thái: `CLOSED`, `OPEN`, `HALF_OPEN`.
>   - Khi tỷ lệ lỗi vượt quá 5 lần liên tiếp, Circuit Breaker lập tức chuyển sang `OPEN`.
>   - Ở trạng thái `OPEN`, tất cả các request tiếp theo được **Fast-Fail ngay trong `< 1ms`** với `HTTP 503 CIRCUIT_BREAKER_TRIGGERED`.
>   - Nhờ Fast-Fail, Order API không bị giữ socket, không bị nghẽn RAM, tiếp tục sống sót và tự động thăm dò phục hồi sau 8 giây cooldown.

---

### ❓ CÂU HỎI 5: Tại sao bạn phải dùng KEDA để scale Worker mà không dùng Kubernetes HPA tiêu chuẩn?
> **Lời giải bảo vệ kiến trúc:**
> - **Điểm mù của HPA tiêu chuẩn:** HPA gốc của Kubernetes chỉ biết đọc số liệu CPU và Memory Utilization từ `metrics-server`.
> - **Bản chất I/O-Bound của Worker:** Worker tiêu thụ Kafka chủ yếu chờ I/O mạng (network wait) và batch insert vào DB. CPU của Worker có thể chỉ ở mức **15–20%**, khiến HPA nghĩ hệ thống đang rảnh rỗi và **không chịu scale up**. Trong khi đó, hàng đợi Kafka Lag có thể đã tích lũy lên tới **50,000 đơn hàng** mà không ai hay biết.
> - **Sức mạnh của KEDA (Event-Driven):**
>   - KEDA cài đặt một Metrics Adapter kết nối trực tiếp vào Kafka Broker để đọc chỉ số **Consumer Lag** thời gian thực của Consumer Group `order-processing-group`.
>   - Cứ mỗi 50 messages lag, KEDA kích hoạt scale thêm 1 Worker Pod (từ 2 lên tối đa 10 Pods). Khi bão tải đi qua và Lag = 0, KEDA tự động scale về lại 2 Pods, tối ưu chi phí hạ tầng (FinOps).

---

### ❓ CÂU HỎI 6: Khi Worker tiêu thụ message từ Kafka để ghi vào PostgreSQL, làm sao bạn đảm bảo tính Idempotency (Không ghi trùng lặp đơn hàng)?
> **Lời giải bảo vệ kiến trúc:**
> - Trong hệ thống phân tán, cơ chế truyền tin của Kafka mặc định là **At-Least-Once delivery** (do có thể xảy ra network timeout khi commit offset).
> - Để tránh việc khách hàng bị tạo 2 đơn hàng khi Worker bị restart giữa chừng:
>   1. `order_id` được sinh duy nhất ngay tại API Ingestion (`ord_<timestamp>_<random_hash>`).
>   2. Trong PostgreSQL, cột `order_id` là **PRIMARY KEY**.
>   3. Lệnh batch insert sử dụng cú pháp:
>      ```sql
>      INSERT INTO orders (order_id, user_id, product_id, quantity, amount, status)
>      VALUES (...)
>      ON CONFLICT (order_id) DO NOTHING;
>      ```
>   4. Nếu một message bị gửi lại lần 2 do Worker crash trước khi commit offset, lệnh `ON CONFLICT DO NOTHING` sẽ âm thầm bỏ qua, đảm bảo 100% tính toàn vẹn dữ liệu (Idempotent Consumer Pattern).

---

### ❓ CÂU HỎI 7: Phân tích CAP Theorem trong hệ thống này: Bạn đã đánh đổi Consistency hay Availability ở những điểm nào?
> **Lời giải bảo vệ kiến trúc:**
> - **Tại tầng Tồn Kho (Inventory Layer):** Chọn **CP (Consistency & Partition Tolerance)**.
>   - Không thể chấp nhận Eventual Consistency ở khâu bán hàng, vì nếu 2 người cùng mua chiếc cuối cùng sẽ dẫn đến bán âm kho (Overselling).
>   - Redis Lua script thực thi kiểm tra chặt chẽ, nếu không chắc chắn có hàng thì từ chối ngay.
> - **Tại tầng Ghi Nhận Đơn Hàng (Order Ingestion Layer):** Chọn **AP (Availability & Partition Tolerance)** với **Eventual Consistency**.
>   - Khách hàng không cần phải chờ đến khi thông tin được ghi vào đĩa của PostgreSQL.
>   - Chỉ cần đơn hàng được đưa vào Kafka buffer thành công, hệ thống lập tức trả về `HTTP 202 QUEUED`. Dữ liệu sẽ đạt trạng thái nhất quán cuối cùng (Eventual Consistency) sau vài chục mili-giây khi Worker xử lý xong.

---

### ❓ CÂU HỎI 8: Trong Kịch bản 4 khi Database Primary bị dính lệnh `SIGKILL -9`, làm sao bạn chứng minh RPO = 0 (Không mất dữ liệu)?
> **Lời giải bảo vệ kiến trúc:**
> - **Cơ chế Transactional Offset Commit:**
>   - Worker chỉ gửi lệnh commit offset lên Kafka sau khi Database Transaction thực thi lệnh `COMMIT` thành công.
>   - Nếu Database chết giữa lúc Worker đang thực thi query:
>     1. Transaction của PostgreSQL tự động bị rollback.
>     2. Worker bắt được exception `ECONNREFUSED` và **KHÔNG commit offset** lên Kafka.
>     3. Batch đơn hàng đó vẫn nằm nguyên vẹn tại offset hiện tại trên partition của Kafka.
>   - Khi Database phục hồi, Worker reconnect lại và đọc lại đúng offset đó để ghi vào DB, đảm bảo **RPO = 0 tuyệt đối**.

---

### ❓ CÂU HỎI 9: Nếu phải triển khai kiến trúc này trên AWS thật cho 10,000 RPS, bạn sẽ Sizing cấu hình phần cứng ra sao (Capacity Planning & FinOps)?
> **Lời giải bảo vệ kiến trúc:**
> - **EKS Worker Nodes:**
>   - Cần tối thiểu **3 node `c6i.2xlarge`** (8 vCPU, 16GB RAM) trải đều qua 3 Availability Zones (AZs) để đảm bảo High Availability và tránh Single Point of Failure.
>   - Cấu hình Karpenter để tự động cấp phát Spot Instances cho Worker khi có bão tải.
> - **Amazon ElastiCache Redis:**
>   - Cluster mode enabled với **1 Primary + 2 Replicas**, instance type **`cache.m6g.xlarge`** (4 vCPU, 12.8GB RAM), Multi-AZ Auto-Failover.
> - **Amazon MSK (Managed Kafka):**
>   - 3 Brokers loại **`kafka.m5.xlarge`** (4 vCPU, 16GB RAM), EBS storage throughput 250 MB/s, 3 Partitions cho topic `orders.events`.
> - **Amazon Aurora PostgreSQL:**
>   - **`db.r6g.2xlarge`** (8 vCPU, 64GB RAM) cho Writer Instance, kèm 2 Reader Instances auto-scaling theo CPU > 60%.

---

### ❓ CÂU HỎI 10: Về mặt Bảo Mật (DevSecOps), kiến trúc này áp dụng các nguyên tắc Zero-Trust nào trên Kubernetes?
> **Lời giải bảo vệ kiến trúc:**
> 1. **Zero-Trust IRSA (IAM Roles for Service Accounts):**
>    - Không bao giờ gán IAM Role trực tiếp cho EC2 Node (Node Instance Profile).
>    - Mỗi Pod (`order-api`, `order-worker`) chỉ được cấp đúng ServiceAccount với quyền tối thiểu (Principle of Least Privilege) thông qua OIDC Provider.
> 2. **Pod Security Standards (PSS - Restricted Mode):**
>    - Toàn bộ Pods chạy dưới quyền `runAsNonRoot: true`, user ID không đặc quyền `1000`.
>    - Vô hiệu hóa leo thang đặc quyền (`allowPrivilegeEscalation: false`).
>    - Xóa toàn bộ Linux Capabilities (`capabilities.drop: ["ALL"]`).
>    - Bật `seccompProfile: { type: RuntimeDefault }` để chặn các syscall nguy hiểm vào nhân Linux.
