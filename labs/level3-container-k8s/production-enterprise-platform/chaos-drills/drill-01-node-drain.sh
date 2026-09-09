#!/usr/bin/env bash
# ==============================================================================
# DRILL 01: ZERO-DOWNTIME NODE EVACUATION (NODE DRAIN TEST)
# ==============================================================================
# Mục tiêu: Mô phỏng kịch bản Worker Node bị hỏng hoặc EKS Rolling Upgrade (Drain Node).
# Tiêu chuẩn thành công: 
#   1. PodDisruptionBudget (PDB) chặn không cho K8s xóa hết Pod cùng lúc.
#   2. PreStop hook (sleep 5) và Graceful Shutdown giữ 0% Drop Request (Zero 502/504).
# ==============================================================================

set -eo pipefail

NAMESPACE="enterprise-platform"
SERVICE_NAME="frontend-service"
DURATION_SECONDS=15
CONCURRENCY=5

echo "======================================================================"
echo " [CHAOS DRILL 01] BẮT ĐẦU DIỄN TẬP: ROLLING DRAIN NODE (ZERO-DOWNTIME)"
echo "======================================================================"

# 1. Kiểm tra Cluster & Pods hiện tại
echo -e "\n>>> 1. Kiểm tra trạng thái Pods và Nodes trước diễn tập:"
kubectl get pods -n "${NAMESPACE}" -o wide --show-labels

NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
if [ ${#NODES[@]} -lt 2 ]; then
    echo -e "\n[CẢNH BÁO] Cluster hiện tại có ít hơn 2 Node (${#NODES[@]} node)."
    echo "Trong môi trường thật (EKS Multi-AZ), cần ít nhất 2 worker nodes để test drain hoàn hảo."
    TARGET_NODE="${NODES[0]}"
else
    # Chọn node đang chứa backend pod
    TARGET_NODE=$(kubectl get pods -n "${NAMESPACE}" -l app=backend -o jsonpath='{.items[0].spec.nodeName}')
fi

echo -e "\n>>> 2. Node mục tiêu sẽ bị DRAIN: [${TARGET_NODE}]"

# 2. Kiểm tra PDB bảo vệ
echo -e "\n>>> 3. Kiểm tra lá chắn PodDisruptionBudget (PDB):"
kubectl get pdb -n "${NAMESPACE}"

# 3. Chuẩn bị URL test (Port-forward hoặc Ingress IP)
echo -e "\n>>> 4. Khởi tạo luồng traffic liên tục để đo lường tỷ lệ rớt gói (Drop Rate)..."
TEMP_DIR=$(mktemp -d)
TRAFFIC_LOG="${TEMP_DIR}/traffic.log"

# Port-forward service ra background nếu test local/offline
kubectl port-forward svc/${SERVICE_NAME} -n "${NAMESPACE}" 18080:80 >/dev/null 2>&1 &
PF_PID=$!
sleep 2

# Bắt đầu vòng lặp bắn traffic
echo "Bắn traffic kiểm thử (20 requests/s) tới http://localhost:18080/ trong ${DURATION_SECONDS}s..."
(
    END_TIME=$((SECONDS + DURATION_SECONDS))
    SUCCESS_COUNT=0
    FAIL_COUNT=0
    while [ $SECONDS -lt $END_TIME ]; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 1 "http://localhost:18080/" || echo "FAILED")
        if [ "$HTTP_CODE" == "200" ]; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            echo "SUCCESS $HTTP_CODE" >> "${TRAFFIC_LOG}"
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
            echo "FAIL $HTTP_CODE" >> "${TRAFFIC_LOG}"
        fi
        sleep 0.05
    done
) &
TRAFFIC_PID=$!

sleep 2

# 4. Thực hiện lệnh DRAIN node (Kích hoạt Chaos)
echo -e "\n>>> 5. [CHAOS INJECTED] Đang kích hoạt: kubectl drain ${TARGET_NODE}..."
echo "Quan sát: PDB sẽ chỉ cho phép xóa từng Pod một, TopologySpreadConstraints sẽ dời Pod sang Node khác."
kubectl drain "${TARGET_NODE}" --ignore-daemonsets --delete-emptydir-data --force --grace-period=30 || true

# Đợi luồng traffic hoàn tất
wait "${TRAFFIC_PID}" || true
kill "${PF_PID}" >/dev/null 2>&1 || true

# 5. Thống kê kết quả
echo -e "\n>>> 6. TỔNG KẾT KẾT QUẢ ĐO LƯỜNG:"
TOTAL_REQS=$(wc -l < "${TRAFFIC_LOG}" || echo "0")
TOTAL_SUCCESS=$(grep -c "SUCCESS" "${TRAFFIC_LOG}" || echo "0")
TOTAL_FAIL=$(grep -c "FAIL" "${TRAFFIC_LOG}" || echo "0")

echo "--------------------------------------------------"
echo "Tổng số requests đã gửi: ${TOTAL_REQS}"
echo "Requests thành công (200): ${TOTAL_SUCCESS}"
echo "Requests thất bại (Drop):  ${TOTAL_FAIL}"
if [ "${TOTAL_REQS}" -gt 0 ]; then
    SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", (${TOTAL_SUCCESS}/${TOTAL_REQS})*100}")
    echo "Tỷ lệ sẵn sàng (Uptime):  ${SUCCESS_RATE}%"
fi
echo "--------------------------------------------------"

# 6. Khôi phục Node (Uncordon)
echo -e "\n>>> 7. Phục hồi trạng thái Cluster: kubectl uncordon ${TARGET_NODE}..."
kubectl uncordon "${TARGET_NODE}"

rm -rf "${TEMP_DIR}"
echo -e "\n>>> KẾT LUẬN CHIẾN TRƯỜNG:"
if [ "${TOTAL_FAIL}" -eq 0 ]; then
    echo "[PASS] XUẤT SẮC! Hệ thống đạt 100% Zero-Downtime nhờ sự phối hợp giữa PDB + preStop Hook + Multi-AZ Topology!"
else
    echo "[ATTENTION] Có ${TOTAL_FAIL} requests bị rớt. Hãy kiểm tra lại thời gian preStop sleep và ALB target de-registration delay."
fi
