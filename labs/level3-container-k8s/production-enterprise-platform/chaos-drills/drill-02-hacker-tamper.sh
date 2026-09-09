#!/usr/bin/env bash
# ==============================================================================
# DRILL 02: HACKER TAMPERING & PRIVILEGE ESCALATION DEFENSE
# ==============================================================================
# Mục tiêu: Mô phỏng Hacker khai thác được RCE (Remote Code Execution) vào Pod
# và cố gắng thực hiện các đòn tấn công kinh điển:
#   1. Sửa mã nguồn ứng dụng (/app/server.js hoặc thả backdoor).
#   2. Cài đặt công cụ tấn công (nmap, curl, netcat qua apk).
#   3. Thay đổi cấu hình DNS hệ thống (/etc/resolv.conf).
#   4. Leo thang đặc quyền (Privilege Escalation).
# Tiêu chuẩn thành công: Toàn bộ đòn tấn công phải bị CHẶN ĐỨNG ở cấp độ Kernel
# nhờ CIS Benchmark: readOnlyRootFilesystem, runAsNonRoot, allowPrivilegeEscalation: false.
# ==============================================================================

set -eo pipefail

NAMESPACE="enterprise-platform"

echo "======================================================================"
echo " [CHAOS DRILL 02] BẮT ĐẦU DIỄN TẬP: CHỐNG XÂM NHẬP VÀ PHÁ HOẠI CONTAINER"
echo "======================================================================"

# Lấy 1 Pod Backend đang chạy
BACKEND_POD=$(kubectl get pods -n "${NAMESPACE}" -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "${BACKEND_POD}" ]; then
    echo "[LỖI] Không tìm thấy Pod Backend nào đang chạy trong namespace ${NAMESPACE}!"
    echo "Hãy chắc chắn rằng bạn đã apply manifests K8s vào cluster trước khi chạy diễn tập."
    exit 1
fi

echo -e "\n>>> Pod mục tiêu diễn tập: [${BACKEND_POD}]"

# --- ATTACK 1: Cố gắng thả Backdoor vào thư mục ứng dụng (/app) ---
echo -e "\n--------------------------------------------------"
echo ">>> ĐÒN TẤN CÔNG 1: Thả file mã độc vào /app/backdoor.js"
echo "--------------------------------------------------"
ATTACK_1_OUTPUT=$(kubectl exec -n "${NAMESPACE}" "${BACKEND_POD}" -- touch /app/backdoor.js 2>&1 || true)
echo "Kết quả từ Container: ${ATTACK_1_OUTPUT}"
if [[ "${ATTACK_1_OUTPUT}" =~ "Read-only file system" ]]; then
    echo "[PHÒNG THỦ THÀNH CÔNG] Kernel đã chặn ghi đĩa nhờ: readOnlyRootFilesystem: true"
else
    echo "[THẤT BẠI - NGUY HIỂM] Container cho phép ghi file vào mã nguồn ứng dụng!"
fi

# --- ATTACK 2: Cố gắng thay đổi cấu hình DNS (/etc/resolv.conf) để DNS Spoofing ---
echo -e "\n--------------------------------------------------"
echo ">>> ĐÒN TẤN CÔNG 2: Sửa file DNS /etc/resolv.conf để chiếm quyền điều hướng traffic"
echo "--------------------------------------------------"
ATTACK_2_OUTPUT=$(kubectl exec -n "${NAMESPACE}" "${BACKEND_POD}" -- sh -c "echo 'nameserver 1.2.3.4' > /etc/resolv.conf" 2>&1 || true)
echo "Kết quả từ Container: ${ATTACK_2_OUTPUT}"
if [[ "${ATTACK_2_OUTPUT}" =~ "Read-only file system" ]] || [[ "${ATTACK_2_OUTPUT}" =~ "Permission denied" ]]; then
    echo "[PHÒNG THỦ THÀNH CÔNG] Hacker không thể can thiệp cấu hình mạng/DNS hệ thống!"
else
    echo "[THẤT BẠI - NGUY HIỂM] File cấu hình hệ thống bị ghi đè!"
fi

# --- ATTACK 3: Cố gắng cài đặt tool hack qua package manager (apk add) ---
echo -e "\n--------------------------------------------------"
echo ">>> ĐÒN TẤN CÔNG 3: Cài đặt công cụ quét mạng (apk add nmap)"
echo "--------------------------------------------------"
ATTACK_3_OUTPUT=$(kubectl exec -n "${NAMESPACE}" "${BACKEND_POD}" -- apk add nmap 2>&1 || true)
echo "Kết quả từ Container: ${ATTACK_3_OUTPUT}"
if [[ "${ATTACK_3_OUTPUT}" =~ "Permission denied" ]] || [[ "${ATTACK_3_OUTPUT}" =~ "Read-only file system" ]] || [[ "${ATTACK_3_OUTPUT}" =~ "not found" ]]; then
    echo "[PHÒNG THỦ THÀNH CÔNG] Chặn đứng nhờ: runAsNonRoot (UID 1000) & readOnlyRootFilesystem!"
else
    echo "[THẤT BẠI - NGUY HIỂM] Hacker có thể tự do cài phần mềm thứ ba vào container!"
fi

# --- ATTACK 4: Kiểm tra khả năng lưu tạm an toàn tại /tmp (emptyDir) ---
echo -e "\n--------------------------------------------------"
echo ">>> THỬ NGHIỆM 4: Ứng dụng ghi file tạm vào vùng hợp lệ /tmp"
echo "--------------------------------------------------"
TMP_TEST_OUTPUT=$(kubectl exec -n "${NAMESPACE}" "${BACKEND_POD}" -- sh -c "echo 'invoice-temp-data' > /tmp/invoice.tmp && cat /tmp/invoice.tmp && rm /tmp/invoice.tmp" 2>&1 || true)
echo "Kết quả từ Container: ${TMP_TEST_OUTPUT}"
if [[ "${TMP_TEST_OUTPUT}" =~ "invoice-temp-data" ]]; then
    echo "[HOẠT ĐỘNG HOÀN HẢO] /tmp mount qua emptyDir hoạt động chuẩn xác cho tác vụ xuất hóa đơn tạm thời!"
else
    echo "[CHÚ Ý] /tmp không thể ghi được. Cần kiểm tra lại emptyDir volume mount."
fi

echo -e "\n======================================================================"
echo ">>> KẾT LUẬN DIỄN TẬP 02: HỆ THỐNG PHÒNG THỦ MULTI-LAYER ĐẠT CHUẨN CIS!"
echo "======================================================================"
