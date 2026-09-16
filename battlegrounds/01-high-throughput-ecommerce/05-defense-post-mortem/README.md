# 🛡️ BẢO VỆ KIẾN TRÚC & SRE POST-MORTEM PACKAGE
## Battleground 01: High-Throughput E-Commerce & Fintech Core Engine (10,000 RPS)

---

## 📌 TỔNG QUAN (OVERVIEW)

Thư mục `05-defense-post-mortem/` đóng gói toàn bộ tài liệu nghiệm thu, báo cáo sự cố chuẩn **Google SRE Blameless Post-Mortem**, cẩm nang vấn đáp kiến trúc chuyên sâu (**Senior SRE / Principal Cloud Architect Q&A Drill**), và danh mục kiểm tra sẵn sàng vận hành thực tế (**Production Readiness Checklist**).

Đây là bằng chứng kỹ thuật và cơ sở lý luận vững chắc nhất để bảo vệ thiết kế kiến trúc trước Hội đồng Kiến trúc sư (Architecture Review Board) và các buổi phỏng vấn kỹ thuật cấp cao (Staff / Principal Engineer).

---

## 🗂️ MỤC LỤC TÀI LIỆU (DOCUMENTATION DIRECTORY)

| Tài Liệu | Mục Đích | Đối Tượng Sử Dụng |
| :--- | :--- | :--- |
| 📋 [01-incident-post-mortem-report.md](./01-incident-post-mortem-report.md) | Báo cáo chi tiết sự cố đợt bão 10,000 RPS, phân tích 5 Whys, dòng thời gian mili-giây, đánh giá RPO=0 / RTO=18s | Incident Commander, Lead SRE, CTO, Stakeholders |
| 🎙️ [02-senior-architectural-qa.md](./02-senior-architectural-qa.md) | Bộ 10 câu hỏi & câu trả lời hóc búa nhất về bài toán tranh chấp dữ liệu, backpressure, distributed failover, và trade-off kiến trúc | Senior/Staff Cloud Engineer, System Architect |
| ✅ [03-sre-production-readiness-checklist.md](./03-sre-production-readiness-checklist.md) | Bảng kiểm 5 tầng (SLO, Hạ tầng, Khả năng chịu lỗi, Bảo mật, Vận hành) trước khi đưa hệ thống lên Production | SRE Team, Platform Team, DevSecOps Lead |

---

## 🎯 ĐIỂM SÁNG KIẾN TRÚC ĐÃ ĐƯỢC CHỨNG MINH TRÊN FLOCI

Trong suốt quá trình triển khai và bắn phá thực nghiệm trên Floci Cloud Emulator:
1. **Zero Overselling Tuyệt Đối:**
   - 63,537 requests xả vào cụm trong 2 phút 40 giây (đỉnh 7,103.58 RPS).
   - Đúng 10,000 đơn hàng được tạo, tồn kho dừng chính xác ở 0.
   - 53,537 requests bị từ chối 409 (Out of Stock) với độ trễ < 15ms.
2. **Zero Data Loss (RPO = 0):**
   - Khi Primary Database bị `kill -9`, toàn bộ giao dịch được đệm an toàn trên Kafka Broker.
   - Database hồi phục sau 18 giây, worker tự động kết nối lại và xử lý hết dữ liệu tồn đọng.
3. **Thoát Hiểm Ngoạn Mục Khỏi Cache Stampede:**
   - Singleflight Pattern đã gom hàng ngàn query đồng thời khi Redis ngắt kết nối thành duy nhất 1 truy vấn tới PostgreSQL, giảm 98.00% áp lực CPU lên Database.
4. **Tự Động Co Giãn Thông Minh Theo Hàng Đợi:**
   - KEDA Operator tự động scale `order-worker` dựa trên độ trễ Kafka Lag thực tế, nhanh hơn nhiều so với việc chỉ dựa vào chỉ số CPU/Memory truyền thống.

---

## 🚀 HƯỚNG DẪN BẢO VỆ DỰ ÁN

Khi trình bày kiến trúc này:
1. **Mở đầu bằng số liệu thực tế:** Trích xuất bảng kết quả thực thi k6 từ [03-chaos-siege-scripts/README.md](../03-chaos-siege-scripts/README.md) và [01-incident-post-mortem-report.md](./01-incident-post-mortem-report.md).
2. **Giải trình sơ đồ dữ liệu:** Sử dụng sơ đồ luồng dữ liệu 3 bước (Fast Path in Redis -> Buffer in Kafka -> Slow Path in RDS) để giải thích tại sao hệ thống không bị nghẽn I/O.
3. **Sẵn sàng phản biện với Q&A Drill:** Nắm vững 10 câu hỏi trọng tâm tại [02-senior-architectural-qa.md](./02-senior-architectural-qa.md) để giải thích sâu về Redis Cluster Hash Slot, Outbox Pattern, Singleflight Goroutine/Promise Deduplication, và CAP Theorem.
