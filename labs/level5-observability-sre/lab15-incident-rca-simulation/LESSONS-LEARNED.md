# Đúc kết Kiến thức & Kinh nghiệm Thực chiến: Quản lý Sự cố & RCA (Lab 15)

---

## 🏛️ 1. Tư duy Cốt lõi của SRE: "Mitigation First" vs "Root Cause Fix"

Trong các kỳ phỏng vấn vị trí Senior SRE / Lead DevOps, câu hỏi kinh điển nhất là:
> *"Khi hệ thống Production đang sập, hành động đầu tiên của bạn là gì?"*

| Hướng tiếp cận sai lầm (Junior/Naive) | Hướng tiếp cận chuẩn mực SRE (Google/Netflix) |
| :--- | :--- |
| Mở mã nguồn ra đọc, cố gắng tìm dòng code lỗi và gõ lệnh fix nóng (Hotfix) trên server. | **MITIGATION FIRST (Cấp cứu trước, điều tra sau):** Dập tắt đám cháy ngay lập tức! |
| Tranh cãi xem ai là người viết đoạn code đó để đổ lỗi. | Giữ cái đầu lạnh: **Rollback về phiên bản an toàn trước đó (`v1.2.2`)** trong vòng 60 giây. |
| Mất hàng giờ đồng hồ khiến khách hàng liên tục bị trừ tiền oan và công ty bị phạt SLA. | Khôi phục dịch vụ trong vòng 5 phút (MTTM), sau đó mới chuyển sang môi trường cô lập để điều tra nguyên nhân gốc rễ (RCA). |

---

## 🕊️ 2. Văn hóa Hậu Sự cố Không Chỉ trích (Blameless Post-Mortem Culture)

Tại sao các tập đoàn công nghệ hàng đầu thế giới (Google, Amazon, Meta, Netflix) lại cấm tuyệt đối việc quy trách nhiệm cá nhân trong báo cáo sự cố?

1. **Con người luôn mắc sai lầm:** Không có lập trình viên nào trên thế giới không bao giờ viết ra một dòng code lỗi.
2. **Hệ thống mới là thủ phạm:** Nếu một lập trình viên có thể vô tình deploy một dòng code làm sập toàn bộ hệ thống thanh toán, thì **chính quy trình CI/CD và hệ thống kiểm thử tự động đã thất bại**, chứ không phải con người!
3. **Hiệu ứng sợ hãi (Culture of Fear):** Nếu bạn kỷ luật hoặc sa thải kỹ sư phạm sai lầm:
   * Các kỹ sư khác sẽ bắt đầu giấu giếm lỗi lầm và nói dối trong các đợt điều tra.
   * Tổ chức sẽ mất đi cơ hội vàng để tìm ra các lỗ hổng chết người tiềm ẩn trong hệ thống.
4. **Văn hóa Blameless:** Tập trung 100% vào: *"Làm thế nào để xây dựng một hệ thống phòng thủ vững chắc đến mức dù một kỹ sư có viết code ẩu cỡ nào thì CI/CD pipeline cũng tự động chặn lại trước khi lọt lên Production?"*

---

## ⏱️ 3. Bộ Tứ Chỉ Số Đo Lường Năng Lực Ứng Phó Sự Cố (SRE Metrics)

Một tổ chức SRE chuyên nghiệp đo lường độ trưởng thành của mình qua 4 chỉ số:

```
[ Sự cố nổ ra ]
      │
      ├── (MTTD: Mean Time to Detect) ──> Thời gian từ lúc lỗi đến khi chuông reo (Mục tiêu: < 3 phút).
      ▼
[ Alert nổ chuông ]
      │
      ├── (MTTA: Mean Time to Acknowledge) ➔ Thời gian On-call thức giấc & nhận phòng War Room (< 5 phút).
      ▼
[ War Room kích hoạt ]
      │
      ├── (MTTM: Mean Time to Mitigate) ➔ Thời gian hạ hỏa (Rollback/Failover) (< 10 phút).
      ▼
[ Dịch vụ sống lại ]
      │
      └── (MTTR: Mean Time to Resolve) ➔ Thời gian sửa dứt điểm bug & đóng hồ sơ RCA (< 24 giờ).
```

---

## 🧩 4. BỨC TRANH TOÀN CẢNH: KẾT NỐI TOÀN BỘ 5 CẤP ĐỘ (THE GRAND SYNTHESIS)

Sau khi hoàn thành đồ án Lab 15, em đã nắm trong tay một chuỗi mắt xích hoàn chỉnh của một kiến trúc Cloud DevSecOps hiện đại:

```
[ LEVEL 1: Linux, Shell & Networking Foundation ]
  └── Nắm vững socket mạng, kernel procfs, log stream để điều tra forensic.

[ LEVEL 2: Infrastructure as Code (Terraform) ]
  └── Tự động hóa provisioning VPC, Subnet, KMS Key, Database RDS cô lập.

[ LEVEL 3: Container Security & AWS EKS (Kubernetes) ]
  └── Đóng gói Docker non-root, PodSecurityContext, Ingress TLS, IRSA Least-Privilege.

[ LEVEL 4: DevSecOps CI/CD Pipeline & GitOps ]
  ├── Lab 10: 5 Cổng kiểm soát bảo mật (SAST, Trivy, SARIF GitHub Security).
  ├── Lab 11: Quản lý Secret tập trung với AWS Secrets Manager & External Secrets Operator (ESO).
  └── Lab 12: Phân phối khai báo với Helm Chart & ArgoCD (Zero Human Kubectl, Auto Self-Healing).

[ LEVEL 5: Observability & SRE (Xử lý sự cố) ]
  ├── Lab 13: Full-stack Observability với Prometheus (RED Method) & Grafana Loki.
  ├── Lab 14: Cảnh báo hướng dịch vụ (SLO/SLI, Error Budget & Alertmanager Routing).
  └── Lab 15: Chỉ huy tác chiến sự cố P1 (Incident Command, 5 Whys RCA & Post-Mortem).
```

---

## ❓ 5. Bộ câu hỏi Phỏng vấn Lead SRE / Principal Architect Q&A

### Q1: "Trong buổi họp Post-Mortem, nếu một lập trình viên thừa nhận họ đã quên khối `release()` gây cạn kiệt Connection Pool, bạn sẽ điều hành buổi họp đó như thế nào?"
> **Trả lời:** "Với tư cách là Lead SRE điều phối buổi họp Blameless Post-Mortem:
> 1. Tôi sẽ cảm ơn lập trình viên đó vì sự trung thực và dũng cảm chia sẻ chi tiết kỹ thuật.
> 2. Tôi sẽ nhấn mạnh trước toàn đội ngũ: *'Lỗi không nằm ở bạn, lỗi nằm ở quy trình phòng thủ của chúng ta'*.
> 3. Tôi sẽ chuyển hướng toàn bộ cuộc thảo luận từ *'Ai đã làm?'* sang *'Tại sao hệ thống cho phép điều đó xảy ra?'*:
>    * Tại sao linter tĩnh không bắt được biến chưa giải phóng?
>    * Tại sao CI pipeline không có bài Stress Test chạy k6 tự động?
> 4. Chúng tôi biến sự cố thành các Action Items cụ thể để nâng cấp hệ thống kiểm thử, đảm bảo lỗi tương tự sẽ bị chặn tự động 100% trong tương lai."

### Q2: "Sự khác nhau giữa Incident Commander (IC) và Operations Lead (Ops Lead) trong một vụ Outage là gì?"
> **Trả lời:**
> * **Incident Commander (IC):** Là người nắm quyền chỉ huy tối cao, chịu trách nhiệm duy trì bức tranh toàn cảnh, giao tiếp với các bên liên quan, bảo vệ đội ngũ khỏi sự quấy rầy của bên ngoài và đưa ra các quyết định then chốt (khi nào rollback, khi nào mở lại traffic). IC **không bao giờ gõ lệnh hay debug code trực tiếp**.
> * **Operations Lead (Ops Lead):** Là cánh tay phải của IC, trực tiếp thực thi các mệnh lệnh kỹ thuật (chạy script rollback, kiểm tra log trong Loki, theo dõi đồ thị Prometheus) và báo cáo kết quả lại cho IC."
