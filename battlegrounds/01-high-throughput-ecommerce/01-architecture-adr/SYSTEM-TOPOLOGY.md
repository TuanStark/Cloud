# 🗺️ System Topology & Data Flow Specification
## Battleground 01: High-Throughput E-Commerce Core Engine

---

## 1. Sơ Đồ Kiến Trúc Tổng Thể (Architectural Topology)

```mermaid
flowchart TD
    Client(["🌐 Người dùng / Khách hàng Flash Sale<br/>(10,000 RPS)"])

    subgraph Edge_Tier["Tầng Biên (Edge & Ingress Tier)"]
        Ingress["🛡️ NGINX Ingress / API Gateway<br/>- SSL Termination<br/>- Rate Limiter (Token Bucket: 200 req/IP/s)<br/>- Metrics Exporter (Port 80/443)"]
    end

    subgraph App_Tier["Tầng Ứng Dụng (Application Tier)"]
        AuthSvc["🔑 Auth & User Service<br/>(Stateless JWT Validator)"]
        OrderAPI["⚡ Order Placement API<br/>- Fast Validation<br/>- Circuit Breaker<br/>- Fast Push to Kafka"]
        WorkerPool["⚙️ Order Processor Workers<br/>(KEDA Autoscaled: 2 -> 10 Pods)<br/>- Idempotent processing<br/>- Stock Decr<br/>- DB Transaction Batching"]
    end

    subgraph Data_Cache_Tier["Tầng Dữ Liệu & Hàng Đợi (Cache, Queue & DB Tier)"]
        RedisCluster[("⚡ Redis In-Memory Cluster (Port 6379)<br/>- Product Catalog Cache<br/>- Hot Inventory Counters (Atomic DECR)<br/>- Anti-Stampede Mutex Locks")]
        KafkaCluster[("📬 Apache Kafka Message Broker (Port 9092)<br/>- Topic: 'orders.pending' (3 Partitions)<br/>- Buffer Shock Absorber<br/>- Retention: 24 Hours")]
        
        subgraph Postgres_HA["Cụm Cơ Sở Dữ Liệu PostgreSQL HA"]
            PG_Master[("👑 PostgreSQL Primary (Master - Port 5432)<br/>- Nhận lệnh Ghi (Writes & Updates)<br/>- WAL Streaming Enabled")]
            PG_Replica[("📖 PostgreSQL Standby (Replica - Port 5433)<br/>- Nhận lệnh Đọc (Read-only Queries)<br/>- Asynchronous / Sync Streaming")]
        end
    end

    subgraph Observability_Tier["Tầng Giám Sát & Phản Ứng (SRE Cockpit)"]
        Prometheus["📊 Prometheus Server (Scrape: 5s)"]
        Grafana["📈 Grafana Dashboard (RED Method + Lag Monitor)"]
        KEDA_Operator["🤖 KEDA Autoscaler Controller"]
    end

    %% Flow Connections
    Client -->|HTTP / HTTPS| Ingress
    Ingress -->|Route /auth| AuthSvc
    Ingress -->|Route /orders| OrderAPI
    Ingress -->|Route /products| OrderAPI

    OrderAPI -->|1. Check Session & Cache| RedisCluster
    OrderAPI -->|2. Push Order Event (3ms)| KafkaCluster
    KafkaCluster -.->|3. Stream Events| WorkerPool

    WorkerPool -->|4. Update Final State| PG_Master
    PG_Master ==>|WAL Streaming Replication| PG_Replica
    OrderAPI -.->|Read Product Details| PG_Replica

    %% Observability Connections
    Prometheus -.-> Ingress
    Prometheus -.-> OrderAPI
    Prometheus -.-> WorkerPool
    Prometheus -.-> KafkaCluster
    Prometheus -.-> PG_Master
    KEDA_Operator -.->|Watch Kafka Lag| KafkaCluster
    KEDA_Operator ==>|Scale Replicas| WorkerPool
```

---

## 2. Luồng Dữ Liệu Chi Tiết (Step-by-Step Data Flow)

### Luồng Đọc (Product Catalog & Inventory Check):
1. Client gửi `GET /api/v1/products/{id}` tới Ingress Gateway.
2. Ingress kiểm tra Rate Limit. Nếu hợp lệ, chuyển tiếp tới `OrderAPI`.
3. `OrderAPI` truy vấn **Redis Cache** trước (`cache-aside` pattern):
   - **Cache Hit (95% trường hợp):** Trả về dữ liệu ngay lập tức ($< 2\text{ms}$).
   - **Cache Miss:** Sử dụng khóa phân tán `SETNX` (Mutex Lock) để chỉ cho phép **duy nhất 1 request** truy vấn xuống `PostgreSQL Standby Replica` để nạp lại cache, ngăn chặn hiện tượng hàng nghìn request cùng lúc đè bẹp Database.

### Luồng Ghi (Order Placement & Payment Reservation):
1. Client gửi `POST /api/v1/orders` kèm giỏ hàng và token xác thực.
2. `OrderAPI` kiểm tra nhanh JWT và số dư tồn kho ảo trên Redis bằng lệnh Atomic `DECR`. Nếu hết hàng, từ chối ngay lập tức ở bộ nhớ ram ($< 1\text{ms}$).
3. Nếu còn hàng, `OrderAPI` gửi một Message JSON vào Kafka Topic `orders.pending`:
   ```json
   {
     "order_id": "ord_9872134",
     "user_id": "usr_5541",
     "product_id": "prod_macbook_m3",
     "quantity": 1,
     "amount": 2000,
     "timestamp": 1726152000
   }
   ```
4. `OrderAPI` phản hồi ngay cho Client HTTP Status `202 Accepted` với payload:
   ```json
   {
     "status": "QUEUED",
     "order_id": "ord_9872134",
     "tracking_url": "/api/v1/orders/ord_9872134/status"
   }
   ```
   *Thời gian xử lý toàn bộ bước này: $< 15\text{ms}$ (Client không phải chờ DB lock).*
5. `Order Processor Worker` tiêu thụ message từ Kafka, mở transaction trên `PostgreSQL Primary Master`, ghi vào bảng `orders` và `order_items`, cập nhật tồn kho chính thức.

---

## 3. Các Điểm Bắn Phá Của Red Team (Siege Attack Targets - Hiệp 3)

Trong Hiệp 3, chúng ta sẽ lần lượt nhắm vào các điểm chí mạng sau:

| Mã Mục Tiêu | Điểm Tấn Công | Phương Pháp Tấn Công | Hiện Tượng Khi Chưa Phòng Thủ |
| :--- | :--- | :--- | :--- |
| **ATK-01** | API Ingress Gateway | Dùng `k6` bơm 10,000 RPS đồng loạt vào endpoint đặt hàng | Server cạn kiệt socket file descriptors, trả về `502 Bad Gateway` hoặc `504 Gateway Timeout`. |
| **ATK-02** | Redis Cache Layer | Đột ngột xóa toàn bộ key hot products (Simulate Cache Avalanche / Flushed cache) | Hàng ngàn thread tràn xuống PostgreSQL cùng lúc, CPU DB vọt lên 100%, sập toàn bộ dịch vụ. |
| **ATK-03** | Kafka Consumer Worker | Bơm poison pill payload lỗi khiến Worker crash lặp đi lặp lại (CrashLoopBackOff) | Kafka Consumer Lag tăng vọt lên hàng chục ngàn message, đơn hàng của khách bị đình trệ vô thời hạn. |
| **ATK-04** | PostgreSQL Primary Master | Thực thi lệnh `docker kill` hoặc ngắt mạng container DB Master đột ngột | Mọi lệnh ghi đơn hàng trả về `500 Internal Server Error`, hệ thống tê liệt hoàn toàn nếu không có failover. |

---

## 4. Các Điểm Can Thiệp Của Blue Team (SRE Defense Shield - Hiệp 4)

| Mã Phòng Thủ | Cơ Chế Phòng Thủ | Thành Phần Phụ Trách | Mục Tiêu SLO Đạt Được |
| :--- | :--- | :--- | :--- |
| **DEF-01** | Token Bucket Rate Limiting | NGINX Gateway | Bảo vệ hạ tầng: Chặn bot spam, đảm bảo mỗi IP chỉ được tối đa 10 req/s, trả về `429 Too Many Requests`. |
| **DEF-02** | Cache Stampede Mutex Lock | Order API (Code level) | Khi cache miss, chỉ 1 thread duy nhất được query DB, 9999 request còn lại đợi 50ms để lấy từ cache vừa warm-up. |
| **DEF-03** | Consumer Lag Autoscaler | KEDA Controller | Khi Lag $> 100$ messages, KEDA tự động scale Worker từ 2 Pods lên 10 Pods trong vòng 10 giây. |
| **DEF-04** | Circuit Breaker (Hystrix / Opossum) | Node.js / Go Service | Khi tỷ lệ lỗi DB $> 50\%$, ngắt mạch tức thì, chuyển hướng sang fallback response an toàn thay vì làm nghẽn thread pool. |
| **DEF-05** | Streaming Replication & Auto-Failover | PostgreSQL + Health Check Script | Nhận diện Primary chết trong 5s, tự động Promote Standby Replica lên làm New Master với **RPO = 0**. |
