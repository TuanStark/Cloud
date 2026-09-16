# ☸️ KUBERNETES DEPLOYMENT MANIFESTS (EKS ON FLOCI)
## Battleground 01: High-Throughput E-Commerce & Fintech Core Engine

Bộ Kubernetes manifests chuẩn Enterprise (v1.30) được thiết kế riêng cho việc triển khai toàn bộ ứng dụng lên cụm **Amazon EKS (`ecommerce-prod-eks`)** trên hạ tầng **Floci Cloud Emulator** (`https://chungkhoanai.dpdns.org/`).

---

## 📁 CẤU TRÚC BỘ MANIFESTS (`02-infrastructure-deployment/k8s/`)

```
02-infrastructure-deployment/k8s/
├── 00-namespace.yaml             # Namespace 'ecommerce' kèm Pod Security Standards (baseline/restricted)
├── 01-serviceaccount-irsa.yaml   # ServiceAccounts gắn IAM Role ARN qua Zero-Trust IRSA
├── 02-configmap-secrets.yaml     # Cấu hình trỏ Aurora RDS (172.18.0.2), Redis & Kafka
├── 03-redis-deployment.yaml      # Cụm Redis In-Memory Hot Inventory & Mutex Lock
├── 04-kafka-deployment.yaml      # Cụm Apache Kafka (KRaft mode v3.7.0) Event Bus
├── 05-order-api-deployment.yaml  # Order Ingestion API (3 Replicas, Pod Anti-Affinity, Probes, Port 8080)
├── 06-order-worker-deployment.yaml # Order Processing Worker Consumer (2 Replicas, Batch PG Writer)
├── 07-ingress-alb.yaml           # AWS Load Balancer Controller Ingress (target-type: ip, WAFv2 Association)
├── 08-autoscaling-hpa.yaml       # HorizontalPodAutoscaler (Scale up đến 20 Pods khi CPU > 70%)
├── kustomization.yaml            # Đóng gói Kustomize (Single-command deployment)
├── deploy-to-floci-eks.sh        # Script tự động đồng bộ kubeconfig và apply lên Floci
└── README.md
```

---

## 🚀 HƯỚNG DẪN TRIỂN KHAI LÊN FLOCI EKS

### Cách 1: Sử dụng Script Tự Động
```bash
cd battlegrounds/01-high-throughput-ecommerce/02-infrastructure-deployment/k8s/
./deploy-to-floci-eks.sh
```

### Cách 2: Triển khai Thủ Công qua Kubectl & Kustomize

1. **Lấy Kubeconfig từ Floci EKS API**:
   ```bash
   AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
   aws --endpoint-url https://chungkhoanai.dpdns.org/ eks update-kubeconfig \
       --name ecommerce-prod-eks \
       --kubeconfig ~/.kube/floci-config
   ```

2. **Nếu kết nối qua SSH Tunnel (khi endpoint là `localhost:6504`)**:
   ```bash
   ssh -L 6504:localhost:6504 <user>@chungkhoanai.dpdns.org
   ```

3. **Áp dụng toàn bộ Manifests lên cụm**:
   ```bash
   kubectl --kubeconfig=~/.kube/floci-config apply -k .
   ```

4. **Kiểm tra trạng thái**:
   ```bash
   kubectl --kubeconfig=~/.kube/floci-config -n ecommerce get pods,svc,ingress,hpa -o wide
   ```

---

## 🛡️ CÁC TIÊU CHUẨN KIẾN TRÚC SENIOR ĐẠT ĐƯỢC
1. **Direct Pod Routing (`target-type: ip`)**: Lưu lượng từ AWS ALB đi thẳng vào IP nội bộ của Pod qua card mạng AWS VPC CNI, bỏ qua hoàn toàn NodePort và iptables `kube-proxy`.
2. **Zero-Trust IRSA**: Pod giao tiếp với AWS STS qua OIDC Provider để nhận temporary credentials, tuyệt đối không dùng access key cứng.
3. **High Availability Pod Topology**: Cấu hình `podAntiAffinity` bắt buộc các Pod của Order API phải nằm rải rác trên các Worker Nodes và Availability Zones khác nhau.
4. **Resilience & Self-Healing**: Liveness/Readiness probes tự động phát hiện và restart các Pod bị nghẽn event-loop hoặc crash connection pool.
