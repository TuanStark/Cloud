# 🥋 Cloud & DevSecOps Engineering Mentorship (0 to 3 YoE)

Chào mừng bạn đến với kho lưu trữ thực hành DevSecOps & Cloud Engineering thực chiến.
Mục tiêu: Đưa bạn từ nền tảng Software/Fullstack Developer lên vị trí **Cloud & DevSecOps Engineer 2–3 năm kinh nghiệm thực chiến**.

---

## 🗺️ Lộ Trình 5 Cấp Độ (15 Bài Lab)

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
├── lab11-secrets-management
└── lab12-gitops-argocd

[Level 5: Observability & SRE (Xử lý sự cố)]
├── lab13-prometheus-grafana-loki
├── lab14-alerting-slo-sli
└── lab15-incident-rca-simulation
```

---

## ⚙️ Cài đặt công cụ cần thiết trên Linux:

1. **AWS CLI v2:** `curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && sudo ./aws/install`
2. **Terraform:** `sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl && curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list && sudo apt-get update && sudo apt-get install terraform`
3. **Docker:** Đã có sẵn trên máy.
