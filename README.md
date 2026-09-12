# 🥋 Cloud & DevSecOps Engineering Mentorship (0 to 3+ YoE)

Chào mừng bạn đến với kho lưu trữ thực hành DevSecOps & Cloud Engineering thực chiến.
Mục tiêu: Đưa bạn từ nền tảng Software/Fullstack Developer lên vị trí **Senior Cloud & DevSecOps Engineer 2–3+ năm kinh nghiệm thực chiến**.

---

## 🧭 Hai Giai Đoạn Huấn Luyện

### 📍 Giai Đoạn 1: Foundation Bootcamp (15 Bài Lab - ĐÃ HOÀN THÀNH 100%)
```
[Level 1: Core Networking & Linux CLI]
├── lab01-vpc-multi-tier          <-- (Hoàn thành)
├── lab02-security-groups-nacl    <-- (Hoàn thành)
└── lab03-vpc-endpoints-cost-opt  <-- (Hoàn thành)

[Level 2: Production Infrastructure as Code (IaC)]
├── lab04-terraform-modules       <-- (Hoàn thành)
├── lab05-state-management-remote <-- (Hoàn thành)
└── lab06-security-linters        <-- (Hoàn thành)

[Level 3: Container & AWS EKS (Kubernetes)]
├── lab07-docker-security        <-- (Hoàn thành)
├── lab08-aws-eks-terraform      <-- (Hoàn thành)
└── lab09-ingress-tls-irsa       <-- (Hoàn thành)

[Level 4: DevSecOps CI/CD Pipeline]
├── lab10-github-actions-security  <-- (Hoàn thành)
├── lab11-secrets-management       <-- (Hoàn thành)
└── lab12-gitops-argocd           <-- (Hoàn thành)

[Level 5: Observability & SRE (Xử lý sự cố)]
├── lab13-prometheus-grafana-loki  <-- (Hoàn thành)
├── lab14-alerting-slo-sli         <-- (Hoàn thành)
└── lab15-incident-rca-simulation <-- (Hoàn thành)
```

### ⚔️ Giai Đoạn 2: Enterprise Battlegrounds (Thực Chiến Tác Chiến - ĐANG TRIỂN KHAI)
> 📘 **Tài liệu Kiến Trúc Cốt Lõi:** [ENTERPRISE-CLOUD-ARCHITECTURE-BLUEPRINT.md](file:///home/stark/Documents/Cloud/ENTERPRISE-CLOUD-ARCHITECTURE-BLUEPRINT.md) (5 Trụ cột AWS, 4 Mẫu hình Doanh nghiệp & Công thức Sizing).  
> ⚔️ **Lộ Trình Tác Chiến:** [BATTLEGROUND-MASTER-PLAN.md](file:///home/stark/Documents/Cloud/BATTLEGROUND-MASTER-PLAN.md) (Kế hoạch 3 Đại Dự án).

1. **Battleground 1: High-Throughput Fintech / E-Commerce Core**
   - *Xây:* Microservices + Apache Kafka + Redis Cluster + PostgreSQL Master-Replica HA.
   - *Đánh:* Flash Sale 10,000 RPS, Cache Avalanche, Kafka Consumer Poison Pill, DB Master Kill.
   - *Thủ:* KEDA Autoscaling, Circuit Breaker, Automatic Failover, Connection Pooling.
2. **Battleground 2: Zero-Trust & Runtime Security Hardening**
   - *Xây:* Kubernetes Cilium CNI (eBPF) + HashiCorp Vault Dynamic Secrets + Falco Runtime.
   - *Đánh:* Lateral Movement, Pod Breakout, Secret Token Exfiltration.
   - *Thủ:* eBPF L7 Policy Isolation, Automated Threat Interception & Pod Eviction.
3. **Battleground 3: Multi-AZ Disaster Recovery & SRE Reliability Runbook**
   - *Xây:* Multi-AZ Pod Topology Spread, Velero Automated Backup & Disaster Recovery.
   - *Đánh:* Simulate Data Center Outage, Data Corruption.
   - *Thủ:* Disaster Recovery Switchover Drill (RTO < 5m, RPO = 0).

---

## ⚙️ Cài đặt công cụ cần thiết trên Linux:

1. **AWS CLI v2:** `curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && sudo ./aws/install`
2. **Terraform:** `sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl && curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list && sudo apt-get update && sudo apt-get install terraform`
3. **Docker & Docker Compose:** Đã có sẵn trên máy.
4. **k6 (Load Testing):** `sudo gpg -k && sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69 && echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list && sudo apt-get update && sudo apt-get install k6`

