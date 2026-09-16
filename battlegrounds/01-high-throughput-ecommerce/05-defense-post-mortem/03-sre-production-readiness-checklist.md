# ✅ SRE PRODUCTION READINESS CHECKLIST (GO-LIVE VERIFICATION)
## Bảng Kiểm Tra Sẵn Sàng Vận Hành Cho Hệ Thống Tải Cực Cao (10,000 RPS)
### Battleground 01: High-Throughput E-Commerce Core Engine

Trước khi mở cổng đón khách cho bất kỳ chiến dịch Flash Sale quy mô lớn nào, toàn bộ các hạng mục dưới đây phải đạt trạng thái **VERIFIED (XÁC NHẬN)**:

---

## 1. TẦNG HẠ TẦNG & MẠNG (INFRASTRUCTURE & NETWORKING)

- [x] **Multi-AZ High Availability:** VPC có 3 Public Subnets, 3 App Subnets và 3 Data Subnets trải đều qua 3 Availability Zones.
- [x] **Pod Anti-Affinity:** Các Pods của `order-api` và `order-worker` được cấu hình phân tán đều qua các Availability Zones khác nhau (`topology.kubernetes.io/zone`).
- [x] **Ingress & WAF:** ALB Ingress Controller được cấu hình `target-type: ip` kèm AWS WAF v2 Web ACL chặn các cuộc tấn công DDoS và Rate Limiting bất thường.
- [x] **DNS & TLS Termination:** HTTPS cert hợp lệ và HTTP tự động chuyển hướng sang HTTPS (`301 Moved Permanently`).

---

## 2. TẦNG CO GIÃN TỰ ĐỘNG & ĐỘ BỀN (SCALABILITY & RESILIENCE)

- [x] **Horizontal Pod Autoscaling (HPA):** Cấu hình HPA cho `order-api` tự động scale theo CPU (> 70%) và Memory (> 80%).
- [x] **Event-Driven Autoscaling (KEDA):** KEDA Operator theo dõi độ trễ hàng đợi **Kafka Consumer Lag** và tự động scale Worker khi lag > 50 messages.
- [x] **Singleflight Request Coalescing:** Đã bọc Singleflight cho tầng Read-through Cache, triệt tiêu 98% áp lực kết nối dồn xuống PostgreSQL khi xảy ra Cache Miss.
- [x] **Circuit Breaker Fast-Fail:** Tự động ngắt mạch trong `< 1ms` khi phụ thuộc Redis hoặc Kafka bị gián đoạn, ngăn chặn sập lan chuyền (Cascading Failure).

---

## 3. TẦNG DỮ LIỆU & BẢO TOÀN TỒN KHO (DATA INTEGRITY & STORAGE)

- [x] **Zero Overselling:** Toàn bộ thao tác trừ kho Flash Sale được thực thi bằng **Atomic Lua Script** trên Redis, đảm bảo tồn kho không bao giờ âm.
- [x] **Idempotent Consumers:** Lệnh batch insert của Worker sử dụng `ON CONFLICT (order_id) DO NOTHING`, loại bỏ hoàn toàn nguy cơ trùng lặp đơn hàng khi retry.
- [x] **Compensating Transactions:** Nếu publish event vào Kafka thất bại, Order API tự động hoàn lại số lượng tồn kho trên Redis (`redis.incrby`).
- [x] **Disaster Recovery (RTO/RPO):** Thử nghiệm `SIGKILL -9` vào Database đạt cam kết **RTO < 30s** và **RPO = 0**.

---

## 4. BẢO MẬT & ZERO-TRUST (DEVSECOPS HARDENING)

- [x] **Zero-Trust IRSA:** ServiceAccounts được phân quyền tối thiểu qua OIDC Provider, không gán IAM Role thừa thãi lên Worker Node.
- [x] **Pod Security Standards (PSS):** Pod chạy dưới quyền `runAsNonRoot: true`, user ID không đặc quyền `1000`, `allowPrivilegeEscalation: false`, và `capabilities.drop: ["ALL"]`.
- [x] **K8s Secret Encryption:** Mật khẩu database và secret keys được mã hóa trong Kubernetes Secret, không hardcode trong Dockerfile hay source code.

---

## 5. KHẢ NĂNG QUAN SÁT & CẢNH BÁO (OBSERVABILITY & SRE ALERTS)

- [x] **RED Method Metrics:** Theo dõi Rate, Errors, Duration cho toàn bộ API qua endpoint `/healthz` và `/metrics/resilience`.
- [x] **CloudWatch Metric Alarms:** Cảnh báo tự động kích hoạt khi CPU > 80%, lỗi 5xx vọt tăng, hoặc Redis cache evictions tăng bất thường.
- [x] **Incident Runbook:** Đã lưu trữ tài liệu xử lý sự cố khẩn cấp tại `04-sre-hardening-defense/failover/failover-runbook.md`.
