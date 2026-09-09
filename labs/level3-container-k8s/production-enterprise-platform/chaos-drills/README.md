# Giai Đoạn 4: Bộ Diễn Tập Sự Cố Chiến Trường (Chaos Drills)

Bộ kịch bản này là vũ khí sát hạch tối thượng để chứng minh nền tảng **Enterprise Cloud-Native Production Platform** đạt chuẩn phòng thủ và khả năng phục hồi (Resilience) theo tiêu chuẩn **CIS Benchmark & AWS Well-Architected Framework**.

---

## 🎯 Danh Sách 3 Kịch Bản Diễn Tập

| Script | Mục tiêu kịch bản | Lá chắn phòng thủ được kiểm chứng | Kỳ vọng thực tế |
| :--- | :--- | :--- | :--- |
| **`drill-01-node-drain.sh`** | Mô phỏng sập Worker Node hoặc EKS Upgrade Rolling Drain | `PodDisruptionBudget` + `preStop: sleep 5` + Graceful Shutdown + `TopologySpread` | **0% Drop Request** (100% Uptime, Zero 502 Bad Gateway) |
| **`drill-02-hacker-tamper.sh`** | Hacker chiếm shell Pod và cố gắng sửa code, đổi DNS, cài công cụ hack | `readOnlyRootFilesystem: true`, `runAsNonRoot: true`, `allowPrivilegeEscalation: false` | **Kernel Chặn 100%** (Read-only FS, Permission Denied) |
| **`drill-03-data-exfiltration.sh`** | Pod gián điệp quét mạng nội bộ và cố gắng trộm file S3 hóa đơn | `NetworkPolicy` (Zero-Trust Default Deny) + `IRSA` (OIDC Token) | **Packet Drop (SYN Timeout)** + **AWS S3 AccessDenied** |

---

## 🚀 Hướng Dẫn Kích Hoạt Diễn Tập

### 1. Cấp quyền thực thi cho các script
```bash
chmod +x chaos-drills/*.sh
```

### 2. Chạy Drill 01: Zero-Downtime Node Evacuation
```bash
./chaos-drills/drill-01-node-drain.sh
```

### 3. Chạy Drill 02: Chống Phá Hoại & Leo Thang Đặc Quyền
```bash
./chaos-drills/drill-02-hacker-tamper.sh
```

### 4. Chạy Drill 03: Chống Chuyển Dịch Ngang (Lateral Movement) & Đánh Cắp S3
```bash
./chaos-drills/drill-03-data-exfiltration.sh
```
