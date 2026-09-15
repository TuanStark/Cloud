# ⚔️ RED TEAM CHAOS SIEGE SUITE
## Kịch Bản Bắn Phá & Thử Tải Cực Hạn (Flash Sale 10,000 RPS)
### Battleground 01: High-Throughput E-Commerce Core Engine

Bộ kịch bản tấn công và tiêm lỗi (Chaos Injection Scripts) được thiết kế theo chuẩn SRE & Red Team thực chiến tại [BATTLEGROUND-MASTER-PLAN.md](file:///home/stark/Documents/Cloud/BATTLEGROUND-MASTER-PLAN.md).

---

## 🎯 CÁC KỊCH BẢN TẤC CHIẾN

```
03-chaos-siege-scripts/
├── k6-flash-sale-10k.js          # Kịch bản k6 dồn tải đa giai đoạn (100 -> 10,000 RPS)
├── 01-siege-flash-sale-10k.sh    # Khai hỏa k6 container & kiểm toán chống bán âm kho
├── 02-chaos-cache-stampede.sh    # Đột quỵ Cache: Kill Redis giữa đỉnh tải 3,000 RPS
├── 03-chaos-kafka-lag-poison.sh  # Đóng băng Worker & Tiêm 3 mẫu Poison Pill độc hại
├── 04-chaos-db-master-kill.sh    # Bắn SIGKILL vào Postgres Primary & Đo RTO/RPO
└── 05-run-all-sieges.sh          # Menu điều khiển tác chiến tổng hợp
```

---

## 🚀 HƯỚNG DẪN KHỞI CHẠY

### 1. Khởi động hệ thống Microservices Runtime
Trước khi bắn phá, đảm bảo cụm container đang chạy:
```bash
cd battlegrounds/01-high-throughput-ecommerce/02-infrastructure-deployment/
docker compose up -d --build
```
Kiểm tra sức khỏe hệ thống:
```bash
curl -s http://localhost:8080/healthz | jq
```

### 2. Khởi chạy Menu Bắn phá Tổng hợp
```bash
cd battlegrounds/01-high-throughput-ecommerce/03-chaos-siege-scripts/
./05-run-all-sieges.sh
```

Hoặc chạy độc lập từng kịch bản:
- **Bão tải 10,000 RPS**:
  ```bash
  ./01-siege-flash-sale-10k.sh
  ```
- **Đột quỵ Cache (Redis Kill)**:
  ```bash
  ./02-chaos-cache-stampede.sh
  ```
- **Tắc nghẽn Kafka & Poison Pill**:
  ```bash
  ./03-chaos-kafka-lag-poison.sh
  ```
- **Trảm tướng Postgres Primary (SIGKILL)**:
  ```bash
  ./04-chaos-db-master-kill.sh
  ```

---

## 📊 CHỈ SỐ NGHIỆM THU (SRE BREAKING POINTS SCORECARD)

| Kịch Bản | Chỉ Số Đánh Giá | Kỳ Vọng Đạt Chuẩn |
| :--- | :--- | :--- |
| **Kịch Bản 1** | Tồn kho sau bão tải (`stock_quantity`) | Đúng bằng 0 (Tuyệt đối không bán âm kho). |
| | P99 Response Latency | `< 500ms` với HTTP 202 Accepted. |
| **Kịch Bản 2** | DB Connections khi mất Cache | Ghi nhận Dogpile Effect và đo giới hạn nghẽn của PG Pool. |
| **Kịch Bản 3** | Phản ứng của Worker với Poison Pill | Bỏ qua message dị dạng và không rơi vào `CrashLoopBackoff`. |
| **Kịch Bản 4** | Downtime & Thất thoát dữ liệu | Đo RTO (`~10-20s`) và tính toàn vẹn giữa Kafka buffer và DB. |
