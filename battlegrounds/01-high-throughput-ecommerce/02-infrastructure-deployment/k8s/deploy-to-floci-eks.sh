#!/usr/bin/env bash
# ============================================================================
# TRIỂN KHAI ỨNG DỤNG LÊN EKS CLUSTER TRÊN FLOCI CLOUD EMULATOR
# Battleground 01: High-Throughput E-Commerce & Fintech Core Engine
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOCI_HOST="${FLOCI_HOST:-13.140.183.90}"
CLUSTER_NAME="${CLUSTER_NAME:-ecommerce-prod-eks}"
AWS_REGION="${AWS_REGION:-us-east-1}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/floci-config}"

echo "============================================================================"
echo "☸️ [FLOCI EKS DEPLOYMENT] BẮT ĐẦU TRIỂN KHAI TOÀN BỘ MICROSERVICES LÊN EKS"
echo "Floci Host:     ${FLOCI_HOST}"
echo "EKS Cluster:    ${CLUSTER_NAME}"
echo "Kubeconfig:     ${KUBECONFIG_PATH}"
echo "============================================================================"

# 1. Kiểm tra / Tự động cấu hình Kubeconfig
echo "[Step 1] Xác thực cấu hình Kubeconfig..."
mkdir -p "$(dirname "${KUBECONFIG_PATH}")"

NEEDS_CONFIG=false
if [ ! -f "${KUBECONFIG_PATH}" ]; then
    NEEDS_CONFIG=true
elif ! kubectl --kubeconfig="${KUBECONFIG_PATH}" cluster-info --request-timeout=20s &>/dev/null; then
    echo "⚠️ Kubeconfig hiện tại chưa kết nối được, tiến hành làm mới..."
    NEEDS_CONFIG=true
fi

if [ "${NEEDS_CONFIG}" = true ]; then
    echo "🔄 Đang lấy Kubeconfig từ container k3s trên Floci Host (${FLOCI_HOST})..."
    if ssh -o BatchMode=yes -o ConnectTimeout=8 "root@${FLOCI_HOST}" "test -e /etc/rancher/k3s/k3s.yaml || docker exec floci-eks-${CLUSTER_NAME} test -e /etc/rancher/k3s/k3s.yaml" 2>/dev/null; then
        ssh "root@${FLOCI_HOST}" "docker exec floci-eks-${CLUSTER_NAME} cat /etc/rancher/k3s/k3s.yaml" \
            | sed "s/127.0.0.1/${FLOCI_HOST}/" \
            | sed "s/localhost/${FLOCI_HOST}/" \
            | sed "s/6443/6500/" > "${KUBECONFIG_PATH}"
        kubectl --kubeconfig="${KUBECONFIG_PATH}" config set-cluster default --insecure-skip-tls-verify=true >/dev/null 2>&1 || true
        chmod 600 "${KUBECONFIG_PATH}"
        echo "✅ Đã trích xuất và lưu Kubeconfig thành công!"
    else
        echo "ℹ️ Thử lấy qua AWS EKS API..."
        export AWS_ACCESS_KEY_ID=test
        export AWS_SECRET_ACCESS_KEY=test
        export AWS_DEFAULT_REGION="${AWS_REGION}"
        FLOCI_API_URL="http://${FLOCI_HOST}:4566"
        aws --endpoint-url "${FLOCI_API_URL}" eks update-kubeconfig \
            --name "${CLUSTER_NAME}" \
            --kubeconfig "${KUBECONFIG_PATH}" 2>/dev/null || true
    fi
fi

# 2. Kiểm tra khả năng kết nối tới Kubernetes API Server
echo "[Step 2] Kiểm tra kết nối tới Kubernetes Control Plane..."
if ! kubectl --kubeconfig="${KUBECONFIG_PATH}" cluster-info --request-timeout=20s; then
    echo "❌ LỖI: Chưa thể kết nối tới API Server của EKS trên Floci (${FLOCI_HOST}:6500)."
    exit 1
fi
echo "✅ Kết nối tới EKS Control Plane thành công!"

# 3. Apply toàn bộ manifests qua Kustomize
echo "[Step 3] Áp dụng toàn bộ manifests lên cụm EKS (Namespace 'ecommerce')..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" apply -k "${SCRIPT_DIR}"

# 4. Kiểm tra trạng thái triển khai
echo "[Step 4] Kiểm tra trạng thái tài nguyên đã khởi tạo:"
echo "--- Danh sách Pods ---"
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce get pods -o wide

echo "--- Danh sách Services ---"
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce get svc -o wide

echo "--- Danh sách HPA ---"
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce get hpa -o wide || true

echo "--- Ingress ALB ---"
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce get ingress -o wide || true

echo "============================================================================"
echo "🎉 HOÀN TẤT TRIỂN KHAI LÊN FLOCI EKS!"
echo "============================================================================"
