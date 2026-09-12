# Lab 15: Incident RCA Simulation & Blameless Post-Mortem

## 📌 Tổng quan đồ án (Lab Overview)

Lab 15 là đồ án tốt nghiệp đỉnh cao, khép lại toàn bộ chương trình đào tạo **Cloud DevSecOps & SRE (5 Cấp độ / 15 Đồ án)**. Đồ án đưa kỹ sư vào vị trí **Incident Commander (Chỉ huy trưởng sự cố)** trực tiếp điều phối và giải quyết một cuộc khủng hoảng Production thực tế (Severity 1 Outage) diễn ra vào đêm Black Friday:
1. **Thiết lập Hiện trường Sự cố**: Mô phỏng bản cập nhật `payment-vault:v1.3.0` chứa lỗi rò rỉ Database Connection Pool và Memory Leak.
2. **Khung Điều phối Chỉ huy Sự cố (Incident Command System)**: Vận hành phòng tác chiến (War Room), phân loại mức độ nghiêm trọng Severity 1.
3. **Cấp cứu Dập lửa Tức thời (Mitigation First)**: Áp dụng nguyên tắc "Stop the bleeding" — lùi phiên bản khẩn cấp bằng Declarative Rollback trong vòng chưa đầy 60 giây.
4. **Phân tích Nguyên nhân Gốc rễ (Root Cause Analysis - RCA)**: Sử dụng Prometheus Metrics, Loki Logs và phương pháp **5 Whys** để truy tìm lỗ hổng hệ thống.
5. **Báo cáo Hậu Sự cố (Blameless Post-Mortem)**: Soạn thảo biên bản tổng kết chuẩn quốc tế theo văn hóa không chỉ trích của Google & Netflix.

---

## 🏗️ Kiến trúc Quy trình Phản ứng Sự cố (Incident Response Architecture)

```
[ 02:18 AM - BÃO SỰ CỐ ] ──> Cạn kiệt 100/100 Connection Pool ➔ Lỗi 5xx vọt lên 65%
                                          │
                                          ▼
[ 02:20 AM - BÁO ĐỘNG ĐỎ ] ──> Prometheus Firing ➔ Alertmanager bắn Webhook P1
                                          │
                                          ▼
[ 02:21 AM - WAR ROOM ] ────> Incident Commander (Tuấn) tiếp nhận vai trò chỉ huy
                                          │
                                          ▼
[ 02:22 AM - DẬP TẮT LỖI ] ──> Kích hoạt Declarative Rollback lùi về bản v1.2.2-stable
                                          │
                                          ▼
[ 02:25 AM - PHỤC HỒI ] ────> 100% Giao dịch thành công (200 OK), Alert Resolved!
                                          │
                                          ▼
[ 02:45 AM - ĐIỀU TRA RCA ] ─> Phân tích 5 Whys, biểu đồ xương cá và bằng chứng số
                                          │
                                          ▼
[ HẬU SỰ CỐ - POST-MORTEM ] ─> Ban hành Action Items: Tích hợp Load Test vào CI/CD (Lab 10)
```

---

## 📂 Cấu trúc Thư mục Đồ án (Project Structure)

```bash
lab15-incident-rca-simulation/
├── 01-incident-simulation/
│   ├── server-buggy.js                # Ứng dụng v1.3.0 chứa mã nguồn lỗi rò rỉ
│   └── Dockerfile                     # Container hiện trường sự cố
├── 02-incident-cockpit/
│   └── INCIDENT-COMMAND-PROTOCOL.md   # Bản quy trình chỉ huy tác chiến khẩn cấp
├── 03-mitigation-rollback/
│   ├── server-stable.js               # Bản dựng v1.2.2 an toàn đã kiểm chứng
│   └── execute-rollback.sh            # Kịch bản Rollback cấp cứu khẩn cấp (< 60s)
├── 04-rca-investigation/
│   └── RCA-INVESTIGATION-REPORT.md    # Báo cáo điều tra pháp y & phân tích 5 Whys
├── 05-post-mortem/
│   └── POST-MORTEM-INCIDENT-2026-09-12.md # Báo cáo Hậu sự cố không chỉ trích chuẩn Google
├── scripts/
│   └── traffic-generator.sh           # Công cụ bơm bão giao dịch kích nổ sự cố
├── prometheus.yml                     # Cấu hình Prometheus giám sát nhịp tim hệ thống
├── docker-compose.yml                 # Điều phối cụm container War Room (Cổng 8082, 9092)
├── README.md                          # Tài liệu hướng dẫn đồ án
└── LESSONS-LEARNED.md                 # Đúc kết kinh nghiệm & Bộ câu hỏi phỏng vấn SRE Trưởng
```

---

## 🚀 Hướng dẫn Diễn tập Toàn bộ Kịch bản Sự cố

### 1. Khởi động hiện trường sự cố
```bash
cd labs/level5-observability-sre/lab15-incident-rca-simulation
docker compose up -d --build
```

### 2. Kích nổ sự cố bằng bão giao dịch
```bash
chmod +x scripts/traffic-generator.sh
./scripts/traffic-generator.sh
```
*Hệ thống sẽ bị cạn kiệt Connection Pool và sập mã 500 từ request thứ 45 trở đi. Health Check trả về HTTP 503.*

### 3. Ra lệnh Cấp cứu Dập lửa (Rollback)
```bash
chmod +x 03-mitigation-rollback/execute-rollback.sh
./03-mitigation-rollback/execute-rollback.sh
```
*Kịch bản tự động hoán đổi image sang bản ổn định `v1.2.2`, khởi động lại pod và nghiệm thu 10/10 request thành công (HTTP 200) trong vòng 60 giây.*

### 4. Đọc hồ sơ Pháp y RCA & Post-Mortem
* Mở [RCA-INVESTIGATION-REPORT.md](file:///home/stark/Documents/Cloud/labs/level5-observability-sre/lab15-incident-rca-simulation/04-rca-investigation/RCA-INVESTIGATION-REPORT.md) để xem phân tích 5 Whys.
* Mở [POST-MORTEM-INCIDENT-2026-09-12.md](file:///home/stark/Documents/Cloud/labs/level5-observability-sre/lab15-incident-rca-simulation/05-post-mortem/POST-MORTEM-INCIDENT-2026-09-12.md) để xem biên bản báo cáo hậu sự cố.
