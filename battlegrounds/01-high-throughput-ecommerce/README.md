# 🏛️ Battleground 01: High-Throughput E-Commerce & Fintech Core
## Kiến Trúc Microservices Chịu Tải Cao (Event-Driven + Caching + Database Replication HA)

---

## 🎯 Mục Tiêu Chiến Trường
Xây dựng một hệ thống thương mại điện tử / fintech có khả năng xử lý **10,000+ RPS** trong các đợt Flash Sale, chịu được sự cố sập cache đột ngột, tắc nghẽn queue, và tự động failover cơ sở dữ liệu mà **không làm mất một xu/đơn hàng nào của khách hàng (Zero Data Loss)**.

---

## 🗺️ Cấu Trúc Thư Mục Tác Chiến

```text
battlegrounds/01-high-throughput-ecommerce/
├── 01-architecture-adr/            <-- Hiệp 1: Bản vẽ thiết kế, Capacity Planning & ADR
│   ├── ADR-001-ECOMMERCE-CORE.md   # Quyết định kiến trúc & đánh giá trade-offs
│   └── SYSTEM-TOPOLOGY.md          # Sơ đồ luồng dữ liệu & điểm nghẽn
├── 02-infrastructure-deployment/   <-- Hiệp 2: Triển khai hạ tầng microservices & data tier
├── 03-chaos-siege-scripts/         <-- Hiệp 3: Scripts bắn phá (k6, DB kill, Kafka poison)
├── 04-sre-hardening-defense/       <-- Hiệp 4: KEDA Autoscaling, Circuit Breaker, Failover
├── 05-defense-post-mortem/         <-- Hiệp 5: Báo cáo phòng thủ & Phỏng vấn Senior SRE
└── README.md                       <-- Tài liệu tổng quan chiến trường
```

---

## 5 Hiệp Đấu Tác Chiến:
1. **Hiệp 1:** Thiết kế Bản vẽ Kiến trúc chuẩn Enterprise & Architecture Decision Record (ADR).
2. **Hiệp 2:** Dựng Cụm Hạ Tầng Thực Chiến (NGINX Ingress, Auth/Order API, Kafka, Redis, Postgres Primary & Standby Replica).
3. **Hiệp 3:** Red Team Tấn Công Toàn Lực (Flash Sale Surge 10,000 RPS, Cache Stampede, Kill Master DB).
4. **Hiệp 4:** Blue Team Kích Hoạt Lá Chắn SRE (KEDA Auto-scale, Circuit Breaker, Mutex Lock, Auto-Failover).
5. **Hiệp 5:** Tổng Kết Chiến Dịch & Phỏng Vấn Bảo Vệ Kiến Trúc Senior (Grill-me Session).
