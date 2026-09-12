# 🔬 BÁO CÁO ĐIỀU TRA PHÁP Y & NGUYÊN NHÂN GỐC RỄ (ROOT CAUSE ANALYSIS - RCA)

**Vụ án Sự cố:** Black Friday Payment Outage - Sự cố Sập Cổng Thanh toán  
**Mức độ nghiêm trọng:** **Severity 1 (P1 - Critical Outage)**  
**Đối tượng điều tra:** Bản cập nhật `payment-vault:v1.3.0`  
**Chủ trì điều tra (Lead Forensic SRE):** Lê Công Tuấn  
**Thời gian điều tra:** 02:45 AM - Sau khi dịch vụ đã được dập tắt bằng Rollback  

---

## 🔎 1. BẰNG CHỨNG PHÁP Y THU THẬP TẠI HIỆN TRƯỜNG (DIGITAL EVIDENCE)

Sau khi Incident Commander hạ lệnh Rollback đưa hệ thống về an toàn, đội ngũ SRE đã niêm phong bản dựng `v1.3.0` và thu thập 3 bằng chứng kỹ thuật không thể chối cãi:

### 📑 Bằng chứng 1: Dấu vết trong Nhật ký (Log Forensics từ Loki)
Trích xuất từ luồng log của container tại thời điểm sập hệ thống ($T_0 + 3\text{ phút}$):
```json
{
  "timestamp": "2026-09-12T02:20:15.102Z",
  "level": "FATAL",
  "status": 500,
  "error": "DB_CONNECTION_POOL_EXHAUSTED",
  "active_connections": 102,
  "max_connections": 100,
  "heap_used_mb": "487.32",
  "message": "FATAL: Connection pool exhausted: 100/100 active connections timeout after 3000ms. Transaction failed!"
}
```
👉 **Kết luận từ Log:** Hệ thống không chết vì thiếu CPU! Hệ thống chết vì **toàn bộ 100 kết nối Database bị chiếm dụng và không chịu nhả ra**, khiến các luồng xử lý giao dịch bị nghẽn (Blocking) và timeout sau 3 giây.

---

### 📈 Bằng chứng 2: Dấu vết trong Đồ thị (Metrics Forensics từ Prometheus)
Truy vấn dữ liệu chuỗi thời gian (TSDB) trong 10 phút xảy ra sự cố:
1. Metric `db_connection_pool_active`:
   * $T_0$: 15 kết nối (Mức bình thường).
   * $T_0 + 60\text{s}$ (Bão traffic ập tới): Tăng vọt theo dốc đứng chạm ngưỡng **100/100**!
   * $T_0 + 120\text{s}$: Nằm bẹp ở mức 100, không giảm dù lưu lượng đã giảm. ➔ **Bằng chứng rõ ràng của Rò rỉ Kết nối (Connection Leak)!**
2. Metric `process_resident_memory_bytes`:
   * Tăng tuyến tính từ 45MB lên **512MB** (Tăng hơn 10 lần chỉ sau 60 requests). ➔ **Bằng chứng của Rò rỉ Bộ nhớ (Memory Leak)!**

---

### 💻 Bằng chứng 3: Mổ xẻ Mã nguồn (Code Diff Forensics)
So sánh Git Diff giữa bản ổn định `v1.2.2` và bản lỗi `v1.3.0`:

```diff
--- a/server-stable.js (v1.2.2)
+++ b/server-buggy.js (v1.3.0)
@@ -48,7 +48,15 @@ const server = http.createServer((req, res) => {
   if (req.url === '/api/v1/charge' && req.method === 'POST') {
-    // v1.2.2: Luôn giải phóng connection sau khi hoàn tất
-    activeConnections = 15;
+    // ❌ v1.3.0: Chiếm dụng kết nối nhưng QUÊN KHỐI FINALLY GIẢI PHÓNG!
+    activeConnections += 2;
+
+    // ❌ v1.3.0: Bơm dữ liệu rác vào mảng toàn cục mà không có cơ chế dọn rác (TTL)!
+    for (let i = 0; i < 5000; i++) {
+      leakedMemoryCache.push({ tx_id: Math.random(), leak_payload: "BLOB_DATA" });
+    }
```

---

## 🎯 2. PHƯƠNG PHÁP 5 WHYS (5 CÂU HỎI TẠI SAO - TRUY VẾT TẬN GỐC)

Một kỹ sư SRE tầm thường sẽ dừng lại ở câu trả lời: *"Do lập trình viên viết code ẩu!"*.  
Nhưng một **Senior SRE / Principal Architect** luôn áp dụng phương pháp **5 Whys của Toyota / Google** để tìm ra lỗ hổng của cả một hệ thống:

```
[ Tại sao 1: Khách hàng không thanh toán được? ]
  └──> Vì API trả về mã lỗi HTTP 500 Internal Server Error.

[ Tại sao 2: API lại trả về mã lỗi HTTP 500? ]
  └──> Vì Connection Pool bị cạn kiệt (100/100) và RAM bị tràn.

[ Tại sao 3: Connection Pool bị cạn kiệt và RAM bị tràn? ]
  └──> Vì trong mã nguồn v1.3.0, lập trình viên quên giải phóng kết nối và nhồi mảng toàn cục.

[ Tại sao 4: Tại sao một đoạn code lỗi ngớ ngẩn như vậy lại lọt qua được môi trường Staging? ]
  └──> Vì ở môi trường Staging chỉ chạy Unit Test với 1-2 request đơn lẻ. Không hề có bài kiểm tra Chịu tải đồng thời (Concurrency / Load Test) để mô phỏng áp lực Black Friday!

[ Tại sao 5: TẠI SAO PIPELINE CI/CD LẠI CHO PHÉP MERGE VÀ DEPLOY MÀ KHÔNG CÓ LOAD TEST? ]
  └──> 🚨 ROOT CAUSE GỐC RỄ: Pipeline GitHub Actions (ở Lab 10) chỉ mới có cổng quét bảo mật (Trivy) và linter, HOÀN TOÀN THIẾU CỔNG KIỂM SOÁT HIỆU NĂNG TỰ ĐỘNG (Automated Performance Quality Gate) trước khi cho phép GitOps sync lên Production!
```

---

## 🐟 3. BIỂU ĐỒ XƯƠNG CÁ (FISHBONE / ISHIKAWA DIAGRAM)

```
CON NGƯỜI (PEOPLE)                    QUY TRÌNH (PROCESS)
Áp lực deadline Black Friday ────┐    ┌──── Thiếu bước Load Test trong Staging
Review code chưa soi kỹ khối DB ─┴──┐ │ ┌── Thiếu quy định kiểm tra Connection Leak
                                    ▼ ▼ │
──────────────────────────────────────────────────────────► [ SỰ CỐ SẬP P1 ]
                                    ▲ ▲ │
Thiếu Circuit Breaker tự ngắt ───┬──┘ │ └── Traffic Black Friday tăng đột biến
K8s thiếu Memory Limits ─────────┘    └──── Connection Pool đặt ngưỡng 100 quá thấp
CÔNG CỤ / HẠ TẦNG (TOOLS)             MÔI TRƯỜNG (ENVIRONMENT)
```

---

## 🛡️ 4. BIỆN PHÁP KHẮC PHỤC TRIỆT ĐỂ (PREVENTIVE ACTION ITEMS)

Để sự cố này **VĨNH VIỄN KHÔNG BAO GIỜ TÁI DIỄN**, SRE ban hành 4 hành động phòng ngừa:

| Cấp độ | Hành động Kỹ thuật (Action Item) | Người phụ trách | Hạn chót | Liên kết Đồ án |
| :--- | :--- | :--- | :--- | :--- |
| **P0 (Khẩn cấp)** | Sửa mã nguồn: Đưa `connection.release()` vào khối `try...finally` bắt buộc và loại bỏ mảng cache rác. | Dev Team | 24 giờ | Mã nguồn App |
| **P1 (Ngăn ngừa)** | **Bổ sung Cổng Load Test vào CI Pipeline**: Chạy k6/Locust tự động bắn 500 RPS trong 1 phút trên môi trường Staging. Nếu phát hiện rò rỉ RAM hoặc Connection ➔ Chặn đứng PR, không cho merge! | DevSecOps Lead (Tuấn) | 3 ngày | **Lab 10 (CI/CD Gates)** |
| **P1 (Cảnh báo)** | **Thêm Prometheus Alerting Rule**: Bổ sung cảnh báo `DBConnectionPoolSaturation` khi connection pool vượt quá 80% trong 1 phút để kỹ sư can thiệp trước khi sập. | SRE Team (Tuấn) | 2 ngày | **Lab 14 (Alerting)** |
| **P2 (Hạ tầng)** | Cấu hình Kubernetes Resource Limits & Requests chặt chẽ và bật Pod AutoScaling (HPA) trong Helm Chart. | Cloud Architect | 1 tuần | **Lab 12 (Helm & K8s)** |
