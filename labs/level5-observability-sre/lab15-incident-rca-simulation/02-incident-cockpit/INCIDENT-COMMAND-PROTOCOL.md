# 🚨 INCIDENT COMMAND PROTOCOL (QUY TRÌNH CHỈ HUY SỰ CỐ PRODUCTION)
**Cấp độ sự cố:** **SEVERITY 1 (P1 - CRITICAL OUTAGE)**  
**Dịch vụ ảnh hưởng:** Payment Vault API (`/api/v1/charge`)  
**Chỉ huy trưởng (Incident Commander):** Lê Công Tuấn  

---

## 🧭 1. Tiêu chí Phân loại Sự cố (Severity Matrix)

| Cấp độ | Định nghĩa | Tiêu chí kích hoạt | Mục tiêu phục hồi (MTTR) |
| :--- | :--- | :--- | :--- |
| 🔴 **P1 (Critical)** | Sự cố tê liệt toàn diện | Lỗi quẹt thẻ thanh toán, doanh thu sụt giảm, vi phạm SLO nghiêm trọng. | **< 10 phút** |
| 🟡 **P2 (Major)** | Suy giảm hiệu năng nặng | Hệ thống chạy chậm (Latency > 2s), chưa sập hoàn toàn nhưng ảnh hưởng diện rộng. | **< 30 phút** |
| 🟢 **P3 (Minor)** | Lỗi giao diện / chức năng phụ | Lỗi hiển thị lịch sử giao dịch, tính năng báo cáo chậm. | **< 4 giờ** |

---

## 📋 2. Bảng Kiểm Tra Tác Chiến 3 Bước (War Room Checklist)

### Bước 1: Tiếp nhận & Nhận diện (Triage)
- [ ] Ghi nhận thời điểm sự cố bắt đầu ($T_0$).
- [ ] Xác nhận mức độ nghiêm trọng: **Severity 1**.
- [ ] Bật phòng họp khẩn cấp War Room và thông báo kênh `#incident-war-room`.

### Bước 2: Cấp cứu dập lửa (Mitigation - Stop the Bleeding)
- [ ] **Hành động tức thời:** Không debug code! Kiểm tra phiên bản vừa deploy gần nhất.
- [ ] **Ra lệnh:** Thực thi **Declarative Rollback** lùi về phiên bản an toàn trước đó (`v1.2.2`).
- [ ] Xác nhận tỷ lệ lỗi 5xx giảm về 0%.

### Bước 3: Điều tra sau sự cố (Root Cause Analysis - RCA)
- [ ] Mở phiên điều tra pháp y (Forensics) trên bản dựng lỗi.
- [ ] Thu thập Logs và Metrics làm chứng cứ.
- [ ] Áp dụng phương pháp **5 Whys** để tìm ra lỗ hổng gốc rễ.
- [ ] Lập biên bản Báo cáo Hậu sự cố (Blameless Post-Mortem).
