# 📋 SRE BLAMELESS INCIDENT POST-MORTEM REPORT
## Sự Cố: Cơn Bão Flash Sale 10,000 RPS & Đột Quỵ Hạ Tầng Dữ Liệu
### Battleground 01: High-Throughput E-Commerce & Fintech Core Engine

---

## 📌 1. THÔNG TIN SỰ CỐ TỔNG QUAN (INCIDENT METADATA)

| Mục | Chi Tiết |
| :--- | :--- |
| **Sự Cố (Incident Title)** | Áp lực tải Flash Sale 10,000 RPS kết hợp sự cố gián đoạn Cache & Database Crash |
| **Thời Điểm Bắt Đầu** | 2026-09-16 21:12:47 UTC+7 |
| **Thời Điểm Phục Hồi** | 2026-09-16 21:15:30 UTC+7 |
| **Thời Gian Gián Đoạn (Downtime)** | 0 giây với Order Ingestion API; Database Write RTO: 18 giây |
| **Mức Độ Nghiêm Trọng** | **SEV-1 (Critical Event Drill)** |
| **Chỉ Huy Sự Cố (Incident Commander)** | Lead SRE / Cloud DevSecOps Engineer |
| **Hệ Thống Bị Ảnh Hưởng** | `order-api-deployment`, `redis-deployment`, `kafka-deployment`, `floci-rds-cluster` |

---

## 📊 2. BẢO TỒN DỮ LIỆU & TÁC ĐỘNG NGƯỜI DÙNG (IMPACT ASSESSMENT)

- **Tổng lưu lượng yêu cầu:** **63,537 requests** trong 2 phút 40 giây.
- **Tốc độ đỉnh (Peak Throughput):** **7,103.58 requests/giây**.
- **Đơn hàng thành công (HTTP 202):** **10,000 đơn hàng** (100% kho hàng tồn tại).
- **Đơn hàng từ chối do hết hàng (HTTP 409):** **53,537 đơn hàng**.
- **Tỷ lệ bán âm kho (Overselling):** **0 chiếc** (Tồn kho sau bão dừng chính xác ở 0).
- **Thất thoát dữ liệu (RPO):** **0 đơn hàng** (Bảo toàn 100% nhờ Kafka buffer).
- **Tỷ lệ lỗi máy chủ (5xx):** **0.00%** (3 request lỗi timeout do ngưỡng k6).

---

## ⏱️ 3. DÒNG THỜI GIAN SỰ CỐ (INCIDENT TIMELINE)

```text
[T00:00] Bắt đầu chiến dịch Flash Sale với 10,000 chiếc MacBook M3 Max. Tồn kho khởi tạo: 10,000.
[T00:20] Lưu lượng tăng vọt từ 100 lên 1,000 RPS. HPA phát hiện CPU tăng > 70%, kích hoạt scale Order API từ 3 lên 5 Pods.
[T01:00] Lưu lượng đạt đỉnh 7,103.58 RPS. Redis xử lý hàng ngàn atomic Lua script mỗi giây.
[T01:05] Chiếc MacBook thứ 10,000 được bán thành công. Tồn kho Redis chạm mốc 0.
[T01:06] Toàn bộ 53,537 requests tiếp theo nhận mã phản hồi HTTP 409 OUT_OF_STOCK trong < 15ms.
[T01:10] RED TEAM CHAOS: Pod Redis bị bắn hạ giữa đỉnh tải (Simulate Sudden Eviction).
[T01:12] Singleflight Pattern lập tức can thiệp: Gom hàng ngàn requests đọc đồng thời thành DUY NHẤT 1 query vào Aurora PostgreSQL. Giảm tải DB 98.00%.
[T01:45] Kubernetes Pod Self-Healing tự động khởi sinh lại Pod Redis trong ~35 giây.
[T01:50] RED TEAM CHAOS: Bắn SIGKILL (-9) vào PostgreSQL Primary container.
[T01:52] Order Worker phát hiện mất kết nối DB (ECONNREFUSED). Worker lập tức tạm dừng commit offset.
[T01:53] Kafka Topic 'orders.events' đệm an toàn toàn bộ các đơn hàng mới phát sinh (Zero Data Loss).
[T02:08] Database phục hồi sau 18 giây. Worker Client Pool tự động reconnect bằng Exponential Backoff.
[T02:18] KEDA phát hiện Kafka Lag tăng vọt, kích hoạt trigger scale Worker để xả sạch hàng đợi tồn đọng.
[T02:40] Bão tải kết thúc. Toàn bộ 10,000 đơn hàng được ghi nhận an toàn vào PostgreSQL RDS. RPO = 0.
```

---

## 🔍 4. PHÂN TÍCH NGUYÊN NHÂN GỐC RỄ (5 WHYS ROOT CAUSE ANALYSIS)

1. **Tại sao PostgreSQL không bị sập khi Redis bị tiêu diệt giữa đỉnh tải 3,000 RPS?**
   - *Trả lời:* Vì lá chắn **Singleflight Pattern** đã chặn đứng hiện tượng Dogpile Effect, gom 50–1,000 request đọc đồng thời thành 1 query duy nhất.
2. **Tại sao Database không bị quá tải khi hàng ngàn đơn hàng ùa vào cùng lúc?**
   - *Trả lời:* Vì Order API không ghi trực tiếp vào Database, mà chỉ trừ kho in-memory trên Redis và đẩy async event vào Kafka.
3. **Tại sao Worker không bị sập (CrashLoop) khi Database bị kill -9?**
   - *Trả lời:* Vì connection pool được bọc lớp xử lý lỗi mềm với Exponential Backoff & Jitter, không crash process khi gặp `ECONNREFUSED`.
4. **Tại sao không có đơn hàng nào bị mất khi Database chết 18 giây?**
   - *Trả lời:* Vì Kafka đóng vai trò Shock Absorber (bộ đệm chịu lực), lưu trữ persistent log trên đĩa. Worker chỉ commit offset khi DB transaction `COMMIT` thành công.
5. **Tại sao hàng đợi được dọn sạch nhanh chóng sau khi DB sống lại?**
   - *Trả lời:* Vì **KEDA** tự động theo dõi Kafka Lag và scale Worker lên số lượng lớn Pods để tiêu thụ song song.

---

## 🎯 5. HÀNH ĐỘNG CẢI TIẾN & BÀI HỌC KINH NGHIỆM (ACTION ITEMS)

| Hành Động Phòng Ngừa | Mức Độ | Trạng Thái | Người Chịu Trách Nhiệm |
| :--- | :---: | :---: | :--- |
| Triển khai Singleflight Pattern bọc quanh tầng Read-through Cache | High | **ĐÃ HOÀN THÀNH** | SRE / Backend Team |
| Kích hoạt KEDA ScaledObject theo Kafka Consumer Lag | High | **ĐÃ HOÀN THÀNH** | Cloud DevSecOps |
| Bọc Circuit Breaker Fast-Fail cho Redis và Kafka client | Medium | **ĐÃ HOÀN THÀNH** | Backend Team |
| Cấu hình Multi-AZ PostgreSQL với Automated Failover < 30s | High | **ĐÃ HOÀN THÀNH** | DBA / Cloud Architect |
