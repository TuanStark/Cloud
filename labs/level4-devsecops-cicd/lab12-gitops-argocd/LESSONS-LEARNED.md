# Đúc kết Kiến thức & Kinh nghiệm Thực chiến: GitOps & Declarative Continuous Delivery (Lab 12)

---

## 🎯 1. 4 Nguyên tắc Cốt lõi của OpenGitOps (OpenGitOps Principles)

Theo chuẩn quốc tế do CNCF (Cloud Native Computing Foundation) ban hành:
1. **Declarative (Tính khai báo)**: Toàn bộ trạng thái mong muốn của hệ thống phải được mô tả dưới dạng khai báo (Declarative Manifests: YAML, Helm, Kustomize), không dùng lệnh mệnh lệnh (Imperative: `kubectl run...`).
2. **Versioned and Immutable (Có phiên bản và Bất biến)**: Trạng thái mong muốn được lưu trữ trên Git. Mỗi thay đổi là một commit có định danh SHA bất biến, có lịch sử người sửa, thời gian và lý do.
3. **Pulled Automatically (Tự động kéo)**: Tác tử phần mềm (Software Agents như ArgoCD/Flux) chạy bên trong môi trường đích và tự động kéo cấu hình về, thay vì CI runner đẩy (push) vào.
4. **Continuously Reconciled (Liên tục đối soát)**: Tác tử liên tục so sánh trạng thái thực tế (Actual State trên K8s) với trạng thái khai báo trên Git (Desired State). Nếu phát hiện sai lệch (Drift), nó sẽ tự động cảnh báo hoặc tự sửa (Self-Healing).

---

## 🛡️ 2. So sánh chuyên sâu: Push-based vs Pull-based CI/CD

| Tiêu chí | Mô hình Push (Jenkins / GitHub Actions cũ) | Mô hình Pull (GitOps với ArgoCD) |
| :--- | :--- | :--- |
| **Vị trí thực thi** | CI Runner đẩy thẳng lệnh vào K8s API | ArgoCD chạy bên trong K8s tự kéo từ Git |
| **Quản lý Kubeconfig** | 🔴 Phải lưu `KUBECONFIG` (quyền cluster-admin) trên CI Server / Secret Repo. Rất dễ bị lộ qua build log hoặc tấn công Supply Chain. | 🟢 **Zero-Credentials CI**: CI Runner hoàn toàn không cần biết IP hay Kubeconfig của cụm K8s. |
| **Bảo mật mạng** | Phải mở Port 6443 của Kubernetes API Server ra Internet cho CI runner truy cập. | K8s API Server có thể để **100% Private**. Không cần mở bất kỳ cổng inbound nào. |
| **Chống Drift (Sửa trộm)** | Không có. Nếu ai đó dùng `kubectl edit` sửa lén trên cluster, CI không hề hay biết. | **Tự động phục hồi (Self-Healing)**: Tự đè lại trạng thái trong Git trong vòng vài chục giây. |
| **Audit Log (Kiểm toán)** | Phân tán giữa CI logs và Kubernetes API audit logs. | **Git là Single Source of Truth**: Xem `git log` là biết chính xác toàn bộ lịch sử hệ thống. |
| **Rollback** | Chạy lại pipeline cũ hoặc can thiệp bằng tay. | Chỉ cần `git revert <commit-sha>`. |

---

## ⚙️ 3. Phân tích Nội tại của ArgoCD (Architecture Deep Dive)

Hệ thống ArgoCD bao gồm 3 thành phần chính:
1. **ArgoCD API Server**: Cung cấp Web UI, CLI và quản lý xác thực RBAC, SSO (Okta, GitHub, GitLab).
2. **ArgoCD Repository Server**: Dịch vụ chuyên trách clone Git repository, phân tích và biên dịch (render) các template như Helm charts hoặc Kustomize thành Kubernetes raw manifests.
3. **ArgoCD Application Controller**: "Trái tim" của hệ thống - là một Kubernetes Controller liên tục thực hiện vòng lặp **Reconciliation Loop**:
   * Gọi Repository Server để lấy Desired State (từ Git).
   * Gọi Kubernetes API Server để lấy Live State (trên cluster).
   * So sánh Diff. Nếu khác biệt: Đánh dấu trạng thái `OutOfSync`. Nếu bật `selfHeal: true`, lập tức phát lệnh điều chỉnh Kubernetes API về đúng bản khai báo trong Git.

---

## 📦 4. Chiến lược Quản lý Đa Môi trường (Multi-Environment GitOps)

Trong môi trường doanh nghiệp lớn, có 3 trường phái quản lý cấu hình:

### Cách 1: Branch-per-Environment (Nhánh dev, staging, prod)
* *Ưu điểm:* Dễ hiểu với người mới bắt đầu.
* *Nhược điểm:* **Rất dễ bị lệch mã nguồn (Configuration Drift giữa các nhánh)** khi merge; lịch sử commit bị rối loạn. Không khuyến khích dùng trong Enterprise.

### Cách 2: Directory-per-Environment với Kustomize
* *Cấu trúc:* `base/` chứa cấu hình chung, `overlays/dev/` và `overlays/prod/` chứa patch.
* *Ưu điểm:* Không dùng template engine phức tạp, thuần YAML. Rất tốt cho hệ thống ít biến số.

### Cách 3: Helm Chart + Values-per-Environment (Lựa chọn tối ưu trong Lab 12)
* *Cấu trúc:* Một bộ Chart template duy nhất (`helm-chart/templates/`), chia tách giá trị ra `values-dev.yaml`, `values-prod.yaml`.
* *Ưu điểm:*
  * **DRY (Don't Repeat Yourself)**: Không lặp lại khai báo Deployment/Service.
  * Tận dụng được hệ sinh thái Helm (quản lý chart version, dependency).
  * Dễ dàng tích hợp với ArgoCD qua thuộc tính `valuesFiles` trong Application manifest.

---

## 💡 5. Bí kíp Vận hành Thực chiến (Production Best Practices)

1. **Tuyệt đối không dùng tag `:latest`**:
   * Tag `:latest` có tính thay đổi (mutable). Khi deploy tag này, Git không thể xác định cụ thể đoạn mã nào đang chạy.
   * Luôn dùng **Immutable Tags**: Semantic Versioning (`v1.2.3`) hoặc Commit SHA (`sha-9a4f21b`).
2. **Tách biệt App Repo và GitOps Config Repo (Two-Repo Pattern)**:
   * **App Repo**: Chứa mã nguồn ứng dụng, unit test, Dockerfile. Quyền truy cập mở cho toàn bộ lập trình viên.
   * **GitOps Config Repo**: Chứa Helm chart, values file, K8s manifests. Phân quyền chặt chẽ (chỉ Tech Lead / DevOps được merge PR). CI Bot chỉ được push vào nhánh dev.
   * Giúp tránh vòng lặp vô tận (Infinite CI loop) khi commit config lại kích hoạt build mã nguồn.
3. **Sử dụng `[skip ci]` khi CI Bot commit**:
   * Khi CI Bot tự động cập nhật image tag vào GitOps repo, luôn kèm cờ `[skip ci]` để tránh kích hoạt lại chính pipeline đó.
4. **Bật PodDisruptionBudget (PDB) trên Production**:
   * Khi ArgoCD thực hiện Rolling Update hoặc node bị bảo trì, PDB đảm bảo số lượng Pod sống sót tối thiểu (ví dụ `minAvailable: 2`) để tránh gián đoạn dịch vụ của khách hàng.

---

## ❓ 6. Bộ câu hỏi Phỏng vấn Cấp cao (Senior DevSecOps Interview Q&A)

### Q1: "Làm thế nào bạn giải quyết bài toán quản lý Secret trong mô hình GitOps khi nguyên tắc là toàn bộ cấu hình phải lưu trên Git?"
> **Trả lời:** "Tuyệt đối không lưu Plaintext Secret lên Git. Doanh nghiệp áp dụng 2 giải pháp chính:
> 1. **External Secrets Operator (ESO)** kết hợp AWS Secrets Manager / HashiCorp Vault (như đã triển khai ở Lab 11): Git chỉ lưu khai báo `ExternalSecret` định danh đường dẫn secret, ESO trên cluster sẽ tự động đồng bộ giá trị thực tế vào K8s Secret.
> 2. **Sealed Secrets (Bitnami)** hoặc **SOPS (Mozilla)**: Mã hóa bất đối xứng secret bằng Public Key trước khi commit lên Git; chỉ có Controller trong cluster nắm Private Key mới giải mã được."

### Q2: "Nếu một kỹ sư trực đêm dùng lệnh `kubectl edit` để sửa tạm thời số replica hoặc image nhằm khắc phục sự cố khẩn cấp, điều gì sẽ xảy ra nếu cụm đang dùng ArgoCD?"
> **Trả lời:** "Nếu ArgoCD Application được cấu hình `syncPolicy.automated.selfHeal: true`, trong vòng chu kỳ quét (mặc định 3 phút hoặc ngay lập tức nếu có event), ArgoCD sẽ phát hiện sự sai lệch (Drift) giữa Actual State và Git. Nó sẽ **tự động ghi đè và hủy bỏ các thay đổi thủ công** của kỹ sư đó về đúng bản khai báo trên Git.
> Để xử lý khẩn cấp đúng quy trình trong GitOps:
> * Cách 1: Tạm thời tắt Auto-sync trên giao diện ArgoCD (`Disable Auto-Sync`), sau khi xử lý xong phải commit cấu hình chuẩn vào Git rồi bật lại.
> * Cách 2: Thực hiện sửa thẳng vào Git và merge commit hotfix (đây là cách chuẩn nhất vì lưu lại audit log)."

### Q3: "Sự khác biệt lớn nhất giữa ArgoCD và FluxCD là gì? Khi nào nên chọn cái nào?"
> **Trả lời:**
> * **ArgoCD**: Cung cấp giao diện Web UI trực quan, quản lý ứng dụng đa cụm (Multi-cluster) mạnh mẽ, phân quyền người dùng (SSO/RBAC) xuất sắc, phù hợp cho các tổ chức lớn cần cho cả Developer và QA theo dõi trạng thái triển khai.
> * **FluxCD**: Kiến trúc module hóa (GitOps Toolkit), nhẹ nhàng hơn, tích hợp sâu vào hệ sinh thái CLI/Kubernetes Controller thuần túy, không có Web UI mặc định nặng nề. Phù hợp cho các đội ngũ yêu thích quản trị thuần code hoặc nhúng GitOps vào platform tùy biến.
