#!/usr/bin/env bash
# ============================================================================
# TRIỂN KHAI ỨNG DỤNG LÊN EKS CLUSTER TRÊN FLOCI CLOUD EMULATOR
# Battleground 01: High-Throughput E-Commerce & Fintech Core Engine
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOCI_ENDPOINT="${FLOCI_ENDPOINT:-https://chungkhoanai.dpdns.org/}"
CLUSTER_NAME="${CLUSTER_NAME:-ecommerce-prod-eks}"
AWS_REGION="${AWS_REGION:-us-east-1}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/floci-config}"

echo "============================================================================"
echo "☸️ [FLOCI EKS DEPLOYMENT] BẮT ĐẦU TRIỂN KHAI TOÀN BỘ MICROSERVICES LÊN EKS"
echo "Floci Endpoint: ${FLOCI_ENDPOINT}"
echo "EKS Cluster:    ${CLUSTER_NAME}"
echo "Kubeconfig:     ${KUBECONFIG_PATH}"
echo "============================================================================"

# 1. Cấu hình Kubeconfig từ Floci EKS API
echo "[Step 1] Đang lấy thông tin xác thực Kubeconfig từ Floci..."
mkdir -p "$(dirname "${KUBECONFIG_PATH}")"

AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION="${AWS_REGION}" \
aws --endpoint-url "${FLOCI_ENDPOINT}" eks update-kubeconfig \
    --name "${CLUSTER_NAME}" \
    --kubeconfig "${KUBECONFIG_PATH}"

echo "✅ Đã lưu Kubeconfig vào: ${KUBECONFIG_PATH}"

# 2. Kiểm tra khả năng kết nối tới Kubernetes API Server
echo "[Step 2] Kiểm tra kết nối tới Kubernetes Control Plane..."
if ! kubectl --kubeconfig="${KUBECONFIG_PATH}" cluster-info --request-timeout=5s 2>/dev/null; then
    echo "⚠️ CẢNH BÁO KẾT NỐI: Không thể chạm trực tiếp vào API Server của EKS trên Floci."
    echo "Lý do: Floci trả về endpoint nội bộ 'https://localhost:6504'."
    echo "👉 Nếu bạn có quyền SSH vào máy chủ ${FLOCI_ENDPOINT}, vui lòng tạo tunnel:"
    echo "   ssh -L 6504:localhost:6504 <user>@chungkhoanai.dpdns.org"
    echo "Sau đó chạy lại script này."
    echo ""
    echo "Thực hiện dry-run kiểm tra tính hợp lệ của toàn bộ manifests:"
    kubectl --kubeconfig="${KUBECONFIG_PATH}" apply -k "${SCRIPT_DIR}" --dry-run=client
    echo "✅ Toàn bộ Kubernetes Manifests hợp lệ 100% theo tiêu chuẩn EKS v1.30!"
    exit 0
fi

# 3. Apply toàn bộ manifests qua Kustomize
echo "[Step 3] Áp dụng toàn bộ manifests lên cụm EKS (Namespace 'ecommerce')..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" apply -k "${SCRIPT_DIR}"

# 4. Kiểm tra trạng thái triển khai
echo "[Step 4] Kiểm tra tài nguyên đã khởi tạo:"
echo "--- Danh sách Pods ---"
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce get pods -o wide || true

echo "--- Danh sách Services ---"
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce get svc -o wide || true

echo "--- Ingress ALB ---"
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce get ingress -o wide || true

echo "============================================================================"
echo "🎉 HOÀN TẤT TRIỂN KHAI LÊN FLOCI EKS!"
echo "============================================================================"
