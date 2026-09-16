# 🛡️ GIAI ĐOẠN 3: THỦ THÀNH (SRE HARDENING & RESILIENCE DEFENSE)
## Bộ Lá Chắn Phòng Thủ Hệ Thống Chịu Tải Cao Cấp Độ Enterprise
### Battleground 01: High-Throughput E-Commerce Core Engine (10,000 RPS)

Tài liệu này tổng hợp toàn bộ các kỹ thuật và cơ chế phòng thủ chuyên sâu được kích hoạt để bảo vệ hệ thống trước các đợt tấn công và tiêm lỗi từ [03-chaos-siege-scripts/](file:///home/stark/Documents/Cloud/battlegrounds/01-high-throughput-ecommerce/03-chaos-siege-scripts/).

---

## 🏛️ 1. CẤU TRÚC THƯ MỤC PHÒNG THỦ

```text
04-sre-hardening-defense/
├── keda/
│   ├── 01-install-keda.sh          # Tự động cài đặt KEDA Operator v2.14 lên Floci EKS
│   └── 02-worker-scaledobject.yaml # ScaledObject tự động scale Worker theo Kafka Consumer Lag
├── resilience/
│   ├── singleflight.js             # Thuật toán Singleflight triệt tiêu Cache Stampede
│   └── circuitBreaker.js           # Finite State Machine 3 trạng thái (CLOSED, OPEN, HALF_OPEN)
├── failover/
│   ├── automated-db-failover.sh    # Kịch bản tự động chuyển mạch và phục hồi Database
│   └── failover-runbook.md         # SRE Runbook ứng phó sự cố Database Disaster Recovery
├── test-defense-shields.sh         # Script kiểm chứng tự động 3 lá chắn phòng thủ
└── README.md                       # Tài liệu hướng dẫn này
```

---

## 🛡️ 2. CHI TIẾT 3 LÁ CHẮN PHÒNG THỦ SRE

### 🔹 Lá Chắn 1: Singleflight Pattern (Chống Cache Stampede / Dogpile Effect)
- **Vấn Đề Giải Quyết:** Trong Kịch bản 2 (Đột quỵ Cache), khi Redis bị tiêu diệt hoặc một key hot bị hết hạn giữa đỉnh tải 3,000 RPS, hàng nghìn requests đồng thời sẽ dồn thẳng xuống Database, làm cạn kiệt Connection Pool và khiến PostgreSQL bị treo cứng.
- **Cơ Chế Hoạt Động:**
  - Triển khai tại [`singleflight.js`](file:///home/stark/Documents/Cloud/battlegrounds/01-high-throughput-ecommerce/04-sre-hardening-defense/resilience/singleflight.js).
  - Thuật toán **Request Coalescing (Gom yêu cầu)**: Quản lý danh sách các query đang chạy (`in-flight`).
  - Khi có 1,000 requests cùng đọc sản phẩm `prod_macbook_m3` bị cache miss, Singleflight chỉ cho phép **ĐÚNG 1 QUERY** gửi xuống PostgreSQL. 999 requests còn lại sẽ chia sẻ chung kết quả của query đó.
  - Giảm tải DB lên tới **99.9%** trong các đợt bão đọc.
- **Giám sát:** Truy cập `/metrics/resilience` để xem tỷ lệ gom yêu cầu (`dbLoadReductionPercentage`).

---

### 🔹 Lá Chắn 2: KEDA Kafka Event-Driven Autoscaler
- **Vấn Đề Giải Quyết:** Kubernetes HPA tiêu chuẩn chỉ giám sát CPU/Memory. Tuy nhiên, Worker xử lý hàng đợi là tác vụ hướng I/O (chờ mạng Kafka và Database), dẫn tới tình trạng CPU chỉ 20% nhưng hàng đợi Kafka Lag đã lên tới 10,000 đơn hàng. HPA không thể tự scale Worker trong tình huống này.
- **Cơ Chế Hoạt Động:**
  - Cài đặt **KEDA Operator v2.14** tại [`keda/01-install-keda.sh`](file:///home/stark/Documents/Cloud/battlegrounds/01-high-throughput-ecommerce/04-sre-hardening-defense/keda/01-install-keda.sh).
  - Khởi tạo [`keda/02-worker-scaledobject.yaml`](file:///home/stark/Documents/Cloud/battlegrounds/01-high-throughput-ecommerce/04-sre-hardening-defense/keda/02-worker-scaledobject.yaml) gắn với `order-worker-deployment`.
  - Giám sát độ trễ hàng đợi: **Mỗi 50 messages lag sẽ kích hoạt tăng thêm 1 Worker Pod** (tối đa 10 Pods).
  - Ngay khi bão tải tràn vào, số lượng Worker tự động nhân bản từ 2 lên 5–10 Pods để tiêu thụ sạch hàng đợi trong tích tắc, sau đó tự động co về 2 Pods khi hết tải.

---

### 🔹 Lá Chắn 3: Circuit Breaker Pattern (Bộ Ngắt Mạch & Fast-Fail)
- **Vấn Đề Giải Quyết:** Khi một dịch vụ phụ thuộc (Redis hoặc Kafka) bị sập hoặc quá tải, các request gửi tới Order API sẽ bị treo 5-10 giây để chờ timeout. Hàng nghìn request treo sẽ làm tràn Event Loop và cạn kiệt sockets, kéo sập toàn bộ API (Cascading Failure).
- **Cơ Chế Hoạt Động:**
  - Triển khai tại [`circuitBreaker.js`](file:///home/stark/Documents/Cloud/battlegrounds/01-high-throughput-ecommerce/04-sre-hardening-defense/resilience/circuitBreaker.js) theo Finite State Machine:
    1. **CLOSED (Bình thường):** Mọi request lưu thông. Nếu số lỗi liên tiếp >= 5 -> Ngắt mạch.
    2. **OPEN (Mở mạch):** TẤT CẢ các request tiếp theo lập tức bị từ chối với thời gian phản hồi siêu tốc (**`< 1ms`** - Fast-Fail), trả về `HTTP 503 CIRCUIT_BREAKER_TRIGGERED` kèm hoàn kho an toàn.
    3. **HALF_OPEN (Thăm dò):** Sau 8 giây cooldown, cho phép 2 request canary đi qua. Nếu thành công -> Đóng mạch lại; nếu thất bại -> Mở mạch tiếp.
- **Giám sát:** Theo dõi trạng thái ngắt mạch tức thời tại `/healthz` và `/metrics/resilience`.

---

## 🚀 3. HƯỚNG DẪN KIỂM CHỨNG LÁ CHẮN PHÒNG THỦ

Để chạy bài kiểm tra tự động xác nhận toàn bộ 3 lá chắn đang bảo vệ hệ thống:

```bash
cd /home/stark/Documents/Cloud/battlegrounds/01-high-throughput-ecommerce/04-sre-hardening-defense
chmod +x *.sh keda/*.sh failover/*.sh
./test-defense-shields.sh
```

---

## 📊 4. SO SÁNH TRƯỚC VÀ SAU KHI GIA CỐ PHÒNG THỦ

| Kịch Bản Sự Cố | Trước Khi Phòng Thủ (Hiệp 2) | Sau Khi Kích Hoạt Lá Chắn (Hiệp 3) |
| :--- | :--- | :--- |
| **Cache Stampede (Mất Redis)** | Hàng ngàn kết nối dồn thẳng xuống PostgreSQL, nguy cơ sập DB Connection Pool. | **Singleflight gom 1,000 requests thành 1 query duy nhất**, DB hoàn toàn bình thản. |
| **Kafka Queue Lag (Dồn ứ đơn hàng)** | Worker giữ nguyên 2 Pods, mất nhiều phút mới tiêu thụ hết hàng đợi. | **KEDA tự động scale Worker lên tối đa 10 Pods** theo độ sâu của Lag, dọn sạch queue trong vài giây. |
| **Phụ thuộc quá tải / treo timeout** | Request bị nghẽn 5-10s chờ timeout, Event Loop cạn kiệt socket. | **Circuit Breaker Fast-Fail trong `< 1ms`**, bảo vệ Order API không bị sập dây chuyền. |
| **Database Primary Crash (SIGKILL)** | Cần can thiệp thủ công bằng tay. | **Automated Reconnect + Exponential Backoff**, Kafka đệm dữ liệu đạt **RPO = 0**. |
