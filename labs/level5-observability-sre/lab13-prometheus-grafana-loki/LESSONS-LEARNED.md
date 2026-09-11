# Đúc kết Kiến thức & Kinh nghiệm Thực chiến: Full-Stack Observability (Lab 13)

---

## 🎯 1. Ba Trụ Cột của Observability: Phân định Ranh giới Sử dụng

Một kỹ sư SRE cấp cao luôn biết khi nào cần dùng trụ cột nào để tối ưu thời gian điều tra sự cố (MTTD & MTTR):

```
                       [ BƯỚC 1: PHÁT HIỆN SỰ CỐ ]
                                    │
                                    ▼
                         📊 METRICS (Prometheus)
             "Hệ thống có đang hỏng không? Cái gì đang hỏng?"
            (Error Rate tăng vọt, CPU chạm 98%, P99 Latency > 2s)
                                    │
                  ┌─────────────────┴─────────────────┐
                  ▼                                   ▼
        [ BƯỚC 2: KHOANH VÙNG NGHẼN ]       [ BƯỚC 3: XÁC ĐỊNH NGUYÊN NHÂN ]
                  │                                   │
                  ▼                                   ▼
         🧭 TRACES (Tempo/Jaeger)             🪵 LOGS (Grafana Loki)
        "Nghẽn ở dịch vụ nào?"               "Dòng code nào sinh ra lỗi?"
  (API Gateway -> Order -> Payment Vault)    (Stack trace, NullPointerException,
                                              Database Connection Timeout)
```

---

## 💡 2. Cuộc cách mạng Kiến trúc: Grafana Loki vs ELK Stack (Elasticsearch)

| Tiêu chí | Elasticsearch (ELK Stack) | Grafana Loki |
| :--- | :--- | :--- |
| **Cơ chế Indexing** | 🔴 **Full-Text Index**: Lập chỉ mục từng từ trong toàn bộ nội dung log. | 🟢 **Label-Only Index**: CHỈ lập chỉ mục các nhãn metadata (`app`, `env`, `status`). |
| **Tiêu tốn RAM** | Rất nặng (Tối thiểu 8GB – 32GB RAM cho cluster Elasticsearch). | Siêu nhẹ (Chỉ cần 512MB – 2GB RAM cho đa số hệ thống vừa và nhỏ). |
| **Chi phí Lưu trữ** | Đắt đỏ (Kích thước Index thường gấp 1.5 – 2 lần kích thước log gốc). | Cực rẻ (Dữ liệu log được nén bằng Snappy/Gzip thành các Chunks, lưu trên AWS S3). |
| **Tốc độ Ingestion** | Dễ bị nghẽn (backpressure) khi có bão log đột biến vì phải index text. | Cực nhanh vì chỉ nén và đẩy thẳng vào storage. |
| **Tích hợp Grafana** | Cần cấu hình plugin phức tạp, syntax Lucene/KQL riêng biệt. | Native First-Class Citizen, cú pháp LogQL tương đồng 100% với PromQL. |

---

## 📐 3. Làm chủ PromQL: Những Điểm Hay Bị Lừa Khi Phỏng Vấn

### 1. Phân biệt `rate()` vs `irate()` vs `increase()`
* **`rate(v[1m])`**:
  * Tính tốc độ tăng trung bình mỗi giây của counter trong cửa sổ thời gian (1 phút).
  * **Tự động xử lý Counter Reset** (khi Pod restart và biến đếm về 0, hàm tự bù trừ).
  * **Khuyên dùng:** Dùng cho mọi biểu đồ cảnh báo (Alerting Rules) và Dashboard vì nó làm mượt các đỉnh nhọn đột biến (noise).
* **`irate(v[1m])` (Instant Rate)**:
  * Chỉ lấy 2 điểm dữ liệu gần nhất trong cửa sổ để tính đạo hàm tức thời.
  * Phản ứng cực nhạy với thay đổi chớp nhoáng, nhưng đồ thị sẽ giật cục (gai góc).
  * **Khuyên dùng:** Chỉ dùng khi cần zoom cận cảnh để soi chi tiết một đợt biến động ngắn hạn.
* **`increase(v[5m])`**:
  * Tính tổng số lượng tăng thêm tuyệt đối trong khoảng thời gian đó.
  * Ví dụ: `increase(http_requests_total{status="500"}[5m])` trả về số lượng chính xác có bao nhiêu lỗi 500 xuất hiện trong 5 phút qua.

### 2. Thuật toán của `histogram_quantile()`
* Prometheus **không lưu trữ từng con số độ trễ cụ thể** của từng khách hàng (vì làm vậy sẽ tốn hàng trăm GB bộ nhớ).
* Thay vào đó, Prometheus gom vào các khoảng bucket (`le="0.1"`, `le="0.5"`).
* Khi chạy hàm `histogram_quantile(0.95, ...)`, Prometheus sử dụng **thuật toán nội suy tuyến tính (Linear Interpolation)** bên trong bucket chứa phân vị thứ 95 để ước tính ra con số độ trễ.
* 💡 **Bí kíp thực chiến:** Thiết kế các mốc bucket (`le`) phải bám sát SLA của doanh nghiệp (ví dụ 100ms, 250ms, 500ms, 1s, 2s). Nếu khoảng cách giữa 2 bucket quá xa nhau, kết quả P95/P99 sẽ có sai số lớn.

---

## ⚠️ 4. Bài học Xương máu: Docker Bind-Mount Traps

Trong Lab 13, chúng ta đã đúc kết được 2 lỗi kinh điển về Mount trong Docker:
1. **Host Path Not Found Trap:**
   * Khi khai báo `- ./my-file.yml:/etc/my-file.yml` mà file `my-file.yml` chưa tồn tại trên máy host, Docker Daemon sẽ **mặc định tạo ra một THƯ MỤC rỗng** có tên `my-file.yml`!
   * Khi container khởi chạy, nó cố bind-mount thư mục đó đè lên file trong image ➔ Ném lỗi `mount ... not a directory`.
2. **Read-Only Parent Mount Trap:**
   * Khi mount một thư mục cha với cờ `:ro` (Read-Only), tuyệt đối không được mount tiếp một thư mục con bên trong nó, vì Docker không thể tạo điểm gắn (`mkdirat ... read-only file system`).
   * **Giải pháp chuẩn:** Luôn tách biệt thư mục cấu hình (`/etc/.../provisioning`) và thư mục tài nguyên (`/var/lib/.../dashboards`).

---

## ❓ 5. Bộ câu hỏi Phỏng vấn Senior SRE / Observability Q&A

### Q1: "Tại sao Prometheus lại chọn kiến trúc PULL thay vì PUSH? Trường hợp nào bắt buộc phải dùng PUSH?"
> **Trả lời:**
> * Prometheus chọn PULL vì:
>   1. **Chống quá tải (Rate Limiting):** Prometheus tự quyết định tốc độ cào (`scrape_interval`), bảo vệ server giám sát không bị nghẽn khi hệ thống bị bão traffic.
>   2. **Phát hiện Pod chết (Liveness Detection):** Kéo không được ➔ Đánh dấu `up == 0` và kích hoạt alert ngay.
> * **Trường hợp dùng PUSH:** Dành cho các tác vụ ngắn hạn (Short-lived Batch Jobs / CronJobs) — những tiến trình sinh ra, chạy 3 giây rồi chết ngay trước khi chu kỳ cào 15s của Prometheus kịp tới. Với trường hợp này, ứng dụng push metrics vào **Prometheus Pushgateway**, sau đó Prometheus cào lại từ Pushgateway.

### Q2: "Làm thế nào để giám sát các Pod có IP thay đổi liên tục trong cụm Kubernetes Production?"
> **Trả lời:** "Trong cụm Kubernetes EKS, chúng tôi không bao giờ cấu hình static IP. Chúng tôi sử dụng **Prometheus Operator** kết hợp với CRD **ServiceMonitor**:
> 1. ServiceMonitor sử dụng Kubernetes Label Selector (`matchLabels`) để dò tìm các `Service` mục tiêu.
> 2. Prometheus Operator tự động lắng nghe Kubernetes API Server, phát hiện các Endpoint IP mới khi Pod scale up/down hoặc restart, và tự động inject vào cấu hình scrape target của Prometheus trong thời gian thực."

### Q3: "Phương pháp RED Method khác gì với phương pháp USE Method trong SRE?"
> **Trả lời:**
> * **RED Method (Rate - Errors - Duration):** Áp dụng cho **Request-driven Services / Microservices (Mức Ứng dụng)**. Tập trung vào trải nghiệm của người dùng cuối (Họ có bị lỗi không? Họ chờ có lâu không?).
> * **USE Method (Utilization - Saturation - Errors):** Áp dụng cho **Resources / Hardware (Mức Hạ tầng)** (CPU, Memory, Disk, Network).
>   * *Utilization:* Tài nguyên đang dùng bao nhiêu %?
>   * *Saturation:* Hàng đợi quá tải (queue length) bao nhiêu?
>   * *Errors:* Thiết bị phần cứng có bị lỗi I/O hay rụng gói mạng không?
