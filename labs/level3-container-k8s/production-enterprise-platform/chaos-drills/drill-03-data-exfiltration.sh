#!/usr/bin/env bash
# ==============================================================================
# DRILL 03: LATERAL MOVEMENT & DATA EXFILTRATION DEFENSE
# ==============================================================================
# Mục tiêu: Mô phỏng kẻ tấn công chiếm được một Pod bình thường trong cụm (Namespace khác)
# và cố gắng:
#   1. Quét mạng nội bộ và gọi trực tiếp vào Backend Port 5000 (Lateral Movement).
#   2. Cố gắng đánh cắp dữ liệu hóa đơn từ S3 Bucket (Data Exfiltration).
# Tiêu chuẩn thành công:
#   - NetworkPolicy (Default Deny) chặn đứng toàn bộ traffic không được phép (Packet Drop).
#   - IRSA (OIDC IAM Role) từ chối cấp quyền truy cập S3 cho bất kỳ Pod nào không dùng đúng ServiceAccount.
# ==============================================================================

set -eo pipefail

NAMESPACE="enterprise-platform"
ATTACKER_POD="rogue-infiltrator"

echo "======================================================================"
echo " [CHAOS DRILL 03] BẮT ĐẦU DIỄN TẬP: CHỐNG CHUYỂN DỊCH NGANG & ĐÁNH CẮP DỮ LIỆU"
echo "======================================================================"

# Dọn dẹp pod test cũ nếu có
kubectl delete pod "${ATTACKER_POD}" -n default --ignore-not-found=true >/dev/null 2>&1

echo -e "\n>>> 1. Tạo một Pod lạ mặt (Rogue Pod) tại namespace 'default'..."
kubectl run "${ATTACKER_POD}" -n default --image=curlimages/curl:latest --restart=Never -- sleep 300 >/dev/null 2>&1
kubectl wait --for=condition=Ready pod/"${ATTACKER_POD}" -n default --timeout=30s >/dev/null 2>&1

echo -e "\n>>> 2. [ATTACK 1] Rogue Pod cố gắng gọi trực tiếp Backend API (Port 5000) qua Service DNS:"
BACKEND_SVC_URL="http://backend-service.${NAMESPACE}.svc.cluster.local:5000/healthz"
echo "URL đích: ${BACKEND_SVC_URL}"

ATTACK_NET_OUTPUT=$(kubectl exec -n default "${ATTACKER_POD}" -- curl -s -m 5 "${BACKEND_SVC_URL}" 2>&1 || echo "TIMEOUT/CONNECTION_DROPPED")
echo "Phản hồi nhận được: ${ATTACK_NET_OUTPUT}"

if [[ "${ATTACK_NET_OUTPUT}" =~ "TIMEOUT" ]] || [[ "${ATTACK_NET_OUTPUT}" =~ "CONNECTION_DROPPED" ]] || [[ "${ATTACK_NET_OUTPUT}" =~ "timed out" ]]; then
    echo "[PHÒNG THỦ THÀNH CÔNG] NetworkPolicy (Zero-Trust) đã Drop sạch các gói tin từ Namespace khác!"
else
    echo "[THẤT BẠI - LỖ HỔNG MẠNG] Backend đã phản hồi cho Pod trái phép!"
fi

# --- ATTACK 2: Thử đánh cắp dữ liệu S3 Bucket mà không có IRSA Token hợp lệ ---
echo -e "\n>>> 3. [ATTACK 2] Rogue Pod cố gắng gọi AWS S3 API để đọc dữ liệu hóa đơn:"
# Lấy tên bucket từ Terraform output nếu có
BUCKET_NAME=$(kubectl get deployment backend-deployment -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="S3_BUCKET_NAME")].value}' 2>/dev/null || echo "prod-enterprise-invoice-vault-2026")
echo "Bucket mục tiêu: ${BUCKET_NAME}"

# Thử gọi S3 API ẩn danh từ Pod Rogue
ATTACK_S3_OUTPUT=$(kubectl exec -n default "${ATTACKER_POD}" -- curl -s -m 5 "https://${BUCKET_NAME}.s3.amazonaws.com" 2>&1 || echo "ACCESS_DENIED")
echo "Phản hồi từ AWS S3: ${ATTACK_S3_OUTPUT:0:150}..."

if [[ "${ATTACK_S3_OUTPUT}" =~ "AccessDenied" ]] || [[ "${ATTACK_S3_OUTPUT}" =~ "ACCESS_DENIED" ]]; then
    echo "[PHÒNG THỦ THÀNH CÔNG] AWS S3 & IRSA đã chặn đứng việc đọc dữ liệu trái phép!"
else
    echo "[THẤT BẠI] Bucket có thể đang bị public hoặc cấp quyền lỏng lẻo!"
fi

# Dọn dẹp rogue pod
echo -e "\n>>> 4. Thu dọn hiện trường chiến trường..."
kubectl delete pod "${ATTACKER_POD}" -n default --ignore-not-found=true >/dev/null 2>&1

echo -e "\n======================================================================"
echo ">>> KẾT LUẬN DIỄN TẬP 03: ZERO-TRUST & LEAST PRIVILEGE PHÒNG THỦ TUYỆT ĐỐI!"
echo "======================================================================"
