#!/usr/bin/env bash
# ============================================================================
# CÀI ĐẶT KEDA OPERATOR LÊN FLOCI EKS CLUSTER
# Battleground 01: High-Throughput E-Commerce & Fintech Core Engine
# ============================================================================
set -euo pipefail

KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/floci-config}"
KEDA_VERSION="v2.14.0"
KEDA_MANIFEST_URL="https://github.com/kedacore/keda/releases/download/${KEDA_VERSION}/keda-2.14.0.yaml"

echo "============================================================================"
echo "🛡️ [SRE HARDENING] CÀI ĐẶT KEDA OPERATOR (KUBERNETES EVENT-DRIVEN AUTOSCALING)"
echo "Phiên bản:   ${KEDA_VERSION}"
echo "Kubeconfig:  ${KUBECONFIG_PATH}"
echo "============================================================================"

# 1. Kiểm tra kết nối tới EKS
echo "[Step 1] Kiểm tra kết nối tới Floci EKS Control Plane..."
if ! kubectl --kubeconfig="${KUBECONFIG_PATH}" cluster-info --request-timeout=15s >/dev/null 2>&1; then
    echo "❌ Lỗi: Không thể kết nối tới Floci EKS!"
    exit 1
fi
echo "✅ Kết nối tới cụm EKS thành công!"

# 2. Kiểm tra nếu KEDA đã được cài đặt
if kubectl --kubeconfig="${KUBECONFIG_PATH}" get namespace keda >/dev/null 2>&1 && \
   kubectl --kubeconfig="${KUBECONFIG_PATH}" -n keda get deployment keda-operator >/dev/null 2>&1; then
    echo "ℹ️ KEDA Operator đã được cài đặt trong namespace 'keda'."
else
    echo "[Step 2] Đang tải và cài đặt KEDA CRDs & Operator từ GitHub Release..."
    kubectl --kubeconfig="${KUBECONFIG_PATH}" apply --server-side -f "${KEDA_MANIFEST_URL}"
    echo "✅ Đã apply KEDA manifests thành công!"
fi

# 3. Đợi KEDA Operator và Metrics Server sẵn sàng
echo "[Step 3] Chờ KEDA Controller & Metrics Server đạt trạng thái Ready..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n keda wait --for=condition=available deployment/keda-operator --timeout=120s
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n keda wait --for=condition=available deployment/keda-metrics-apiserver --timeout=120s

echo "============================================================================"
echo "🎉 KEDA OPERATOR ĐÃ SẴN SÀNG TRÊN FLOCI EKS!"
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n keda get pods -o wide
echo "============================================================================"
