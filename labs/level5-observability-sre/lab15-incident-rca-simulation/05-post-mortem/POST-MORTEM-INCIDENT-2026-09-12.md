# 📑 BÁO CÁO HẬU SỰ CỐ KHÔNG CHỈ TRÍCH (BLAMELESS POST-MORTEM REPORT)

**Tên sự cố:** Black Friday Payment Vault Connection Pool Exhaustion & Memory Spike  
**Ngày xảy ra sự cố:** 2026-09-12  
**Chỉ huy trưởng sự cố (Incident Commander):** Lê Công Tuấn  
**Đội ngũ tham gia:** Fintech Core Team, SRE Team, DevSecOps Team  
**Mức độ nghiêm trọng:** **Severity 1 (P1 - Critical Outage)**  
**Trạng thái sự cố:** **RESOLVED (ĐÃ GIẢI QUYẾT TRIỆT ĐỂ)**  

---

## 📊 1. TỔNG KẾT TÁC ĐỘNG NGHIỆP VỤ (EXECUTIVE SUMMARY)

Vào lúc 02:18 AM ngày 12/09/2026, trong đợt mở bán sớm sự kiện Black Friday, cổng thanh toán `payment-vault` gặp sự cố gián đoạn dịch vụ nghiêm trọng do cạn kiệt Connection Pool kết hợp với rò rỉ bộ nhớ sau khi deploy bản cập nhật `v1.3.0`.

* **Tổng thời gian gián đoạn dịch vụ (Total Downtime):** **7 phút** (02:18 AM – 02:25 AM).
* **Thời gian phát hiện sự cố (MTTD - Mean Time to Detect):** **2 phút** (Nhờ Alertmanager P1 Alert).
* **Thời gian cấp cứu dập lửa (MTTM - Mean Time to Mitigate):** **5 phút** (Bằng quy trình Declarative Rollback).
* **Khách hàng bị ảnh hưởng:** Ước tính 1,420 lượt giao dịch quẹt thẻ bị trả về mã lỗi HTTP 500.
* **Tác động Tài chính & Hợp đồng SLA:**
  * **Thiệt hại tài chính trực tiếp:** **0 VNĐ**.
  * **Vi phạm cam kết SLA đối tác:** **KHÔNG VI PHẠM**.
  * 👉 *Lý do:* Hệ thống chỉ gián đoạn 7 phút, nằm hoàn toàn trong **vùng đệm an toàn 172.8 phút** giữa SLO (99.9%) và SLA (99.5%) đã thiết kế ở Lab 14!

---

## ⏱️ 2. DÒNG THỜI GIAN DIỄN BIẾN SỰ CỐ (CHRONOLOGICAL TIMELINE)

*(Toàn bộ thời gian được chuẩn hóa theo múi giờ ICT - UTC+7)*

* **02:15 AM ($T_0$):** Bản cập nhật `payment-vault:v1.3.0` được CD pipeline triển khai lên production sau khi vượt qua các bài Unit Test ở môi trường Staging.
* **02:17 AM ($T_0 + 2\text{m}$):** Bão giao dịch Black Friday ập tới với tốc độ 30 requests/giây.
* **02:18 AM ($T_0 + 3\text{m}$):** Connection Pool chạm kịch trần 100/100 kết nối do các luồng không giải phóng connection.
* **02:19 AM ($T_0 + 4\text{m}$):** Tỷ lệ lỗi 5xx vọt lên 65%. Cảnh báo `High5xxErrorRate` chuyển sang trạng thái `Pending` trên Prometheus.
* **02:20 AM ($T_0 + 5\text{m}$):** Hết thời gian lọc nhiễu (`for: 1m`), Prometheus kích hoạt trạng thái `Firing`. Alertmanager bắn Webhook khẩn cấp P1 tới điện thoại của SRE On-call (Tuấn).
* **02:21 AM ($T_0 + 6\text{m}$):** Tuấn thức giấc, tiếp nhận vai trò **Incident Commander**, kích hoạt phòng tác chiến khẩn cấp (War Room) và tuyên bố sự cố **Severity 1**.
* **02:22 AM ($T_0 + 7\text{m}$):** Tuấn ra lệnh thực thi nguyên tắc *"Mitigation First"* — không đọc code debug, lập tức ra lệnh **Declarative Rollback** về bản ổn định `v1.2.2`.
* **02:23 AM ($T_0 + 8\text{m}$):** Kịch bản rollback khởi động lại pod với image `v1.2.2-stable`.
* **02:24 AM ($T_0 + 9\text{m}$):** Kiểm tra nghiệm thu 10 giao dịch thử nghiệm: 10/10 thành công (HTTP 200). Health Check trả về `HEALTHY`.
* **02:25 AM ($T_0 + 10\text{m}$):** Tỷ lệ lỗi toàn hệ thống giảm về 0%. Alertmanager gửi thông báo `[ALERT RESOLVED]`. Tuyên bố dập tắt đám cháy thành công!
* **02:45 AM ($T_0 + 30\text{m}$):** Bắt đầu phiên điều tra pháp y (Forensics RCA) trên môi trường cô lập.

---

## 🔍 3. NGUYÊN NHÂN GỐC RỄ & CƠ CHẾ KÍCH HOẠT (ROOT CAUSE & TRIGGER)

* **Cơ chế Kích hoạt (Trigger):** Lưu lượng quẹt thẻ tăng đột biến gấp 10 lần nhân dịp mở bán sớm Black Friday.
* **Nguyên nhân Kỹ thuật Trực tiếp (Direct Cause):** Đoạn mã trong `server-buggy.js` (v1.3.0) mượn kết nối từ pool nhưng không đặt lệnh `release()` vào khối `finally`. Dưới áp lực concurrency, 100 kết nối bị chiếm dụng vĩnh viễn, dẫn đến nghẽn cổ chai (blocking starvation) và timeout sau 3000ms.
* **Nguyên nhân Gốc rễ Hệ thống (Systemic Root Cause):**
  * Quy trình CI/CD (Lab 10) chỉ có cổng kiểm tra cú pháp và quét bảo mật mã tĩnh (SAST Trivy).
  * **Hoàn toàn thiếu cổng Kiểm thử Chịu tải Tự động (Automated Concurrency / Load Testing Gate)** trước khi cho phép PR được merge vào nhánh chính. Do đó, các lỗi liên quan đến rò rỉ tài nguyên dưới áp lực cao không thể bị phát hiện ở môi trường Dev/Staging.

---

## ⚖️ 4. ĐÁNH GIÁ: ĐIỂM TỐT, ĐIỂM YẾU & YẾU TỐ MAY MẮN

### 🟢 Điểm làm rất tốt (What Went Well):
1. **Hệ thống cảnh báo hoạt động hoàn hảo:** Alertmanager phát hiện và réo chuông chỉ sau 2 phút, giúp đội ngũ tiếp cận sự cố trước khi mạng xã hội kịp bùng nổ.
2. **Kỷ luật chỉ huy chuẩn xác:** Incident Commander giữ vững nguyên tắc "Mitigation First", kiên quyết rollback thay vì cố gắng sửa code nóng (hotfix) trong lúc hoảng loạn.
3. **Thời gian dập lửa siêu tốc:** Quy trình Rollback chỉ mất chưa đầy 60 giây nhờ kiến trúc Declarative Delivery đã chuẩn hóa từ Lab 12.

### 🔴 Điểm cần cải thiện (What Went Poorly):
1. Không có cảnh báo sớm về độ bão hòa kết nối Database (ví dụ cảnh báo khi pool đạt 80%) để ngăn chặn trước khi sập.
2. Thiếu cơ chế Circuit Breaker (Cầu dao tự ngắt) ở tầng Gateway khi backend bị nghẽn.

### 🍀 Yếu tố may mắn (Where We Got Lucky):
Sự cố nổ ra lúc 02:18 sáng (đợt mở bán sớm) thay vì 12:00 trưa (đỉnh điểm Black Friday). Nhờ đó, số lượng giao dịch bị rớt chỉ dừng lại ở con số 1,420 thay vì hàng trăm nghìn đơn hàng.

---

## 📋 5. KẾ HOẠCH HÀNH ĐỘNG PHÒNG NGỪA (PREVENTATIVE ACTION ITEMS)

| Mã Ticket | Mức độ | Hành động Kỹ thuật Ngăn chặn | Người chịu trách nhiệm | Hạn chót |
| :--- | :--- | :--- | :--- | :--- |
| **FIN-P0-01** | 🔴 P0 | Sửa dứt điểm mã nguồn: Đưa `connection.release()` vào khối `finally` bắt buộc và loại bỏ mảng rò rỉ RAM. | Dev Lead | 24 giờ |
| **SRE-P1-02** | 🟡 P1 | **Tích hợp k6 Load Test vào CI/CD Pipeline (Lab 10):** Tự động bắn 500 RPS trong 1 phút ở Staging. Nếu phát hiện rò rỉ connection ➔ Chặn đứng PR không cho merge. | SRE Lead (Tuấn) | 3 ngày |
| **SRE-P1-03** | 🟡 P1 | **Bổ sung Prometheus Alerting Rule (Lab 14):** Cảnh báo `DBConnectionPoolSaturation` khi pool vượt quá 80% trong 1 phút. | SRE Lead (Tuấn) | 2 ngày |
| **ARCH-P2-04**| 🟢 P2 | Cấu hình Kubernetes PodDisruptionBudget (PDB) và HPA scale pod tự động theo CPU/RAM trong Helm Chart (Lab 12). | Cloud Architect | 1 tuần |
