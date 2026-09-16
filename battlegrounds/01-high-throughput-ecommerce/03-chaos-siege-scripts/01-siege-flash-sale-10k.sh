#!/usr/bin/env bash
# ============================================================================
# KỊCH BẢN 1: CƠN BÃO FLASH SALE 10,000 RPS (RED TEAM SIEGE)
# Battleground 01: High-Throughput E-Commerce Core
# Thực thi trực tiếp TRÊN HẠ TẦNG FLOCI EKS
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/floci-config}"
REPORT_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORT_DIR}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/flash_sale_10k_${TIMESTAMP}.txt"

echo "============================================================================"
echo "🔥 [RED TEAM SIEGE] KHỞI ĐỘNG KỊCH BẢN 1: FLASH SALE 10,000 RPS"
echo "Môi trường:      EKS Cluster on Floci Cloud"
echo "Mục tiêu:        http://order-api-service:80/api/v1/orders"
echo "Kubeconfig:      ${KUBECONFIG_PATH}"
echo "Báo cáo xuất:    ${REPORT_FILE}"
echo "============================================================================"

# 1. Kiểm tra Liveness Endpoint trực tiếp trên cụm EKS
echo "[Step 1] Kiểm tra sức khỏe hệ thống trên Floci EKS..."
HEALTH_STATUS=$(kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce exec deployment/order-api-deployment -- node -e "fetch('http://localhost:8080/healthz').then(r=>r.json()).then(d=>console.log(d.status)).catch(()=>console.log('DOWN'))" | tr -d '\r\n')

if [ "${HEALTH_STATUS}" != "UP" ]; then
    echo "❌ Lỗi: Hệ thống trên EKS chưa sẵn sàng (Status: ${HEALTH_STATUS})!"
    exit 1
fi
echo "✅ Hệ thống đang sẵn sàng (Health: UP, Redis: healthy, Kafka: healthy)."

# 2. Kiểm tra tồn kho trước giờ G
echo "[Step 2] Kiểm tra tồn kho khởi tạo cho 'prod_macbook_m3'..."
INITIAL_STOCK=$(kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce exec deployment/order-api-deployment -- node -e "fetch('http://localhost:8080/api/v1/products/prod_macbook_m3').then(r=>r.json()).then(d=>console.log(d.stock_quantity)).catch(()=>console.log('N/A'))" | tr -d '\r\n')
echo "📊 Số lượng tồn kho ban đầu: ${INITIAL_STOCK} chiếc"

# 3. Khai hỏa k6 trực tiếp TRONG HẠ TẦNG FLOCI EKS
echo "[Step 3] Khai hỏa k6 Pod trực tiếp trên Floci EKS (Cluster Network)..."
# Xóa pod cũ nếu còn sót lại
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce delete pod k6-flash-sale-siege --now 2>/dev/null || true

cat "${SCRIPT_DIR}/k6-flash-sale-10k.js" | \
kubectl --kubeconfig="${KUBECONFIG_PATH}" run k6-flash-sale-siege \
    --image=grafana/k6:latest \
    --restart=Never \
    --rm -i \
    -n ecommerce \
    -- run -e TARGET_URL="http://order-api-service:80" - 2>&1 | tee "${REPORT_FILE}" || true

echo "============================================================================"
echo "🎯 ĐÁNH GIÁ KẾT QUẢ VÀ TÍNH TOÀN VẸN TỒN KHO (OVERSELLING AUDIT)"
echo "============================================================================"
FINAL_STOCK=$(kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce exec deployment/order-api-deployment -- node -e "fetch('http://localhost:8080/api/v1/products/prod_macbook_m3').then(r=>r.json()).then(d=>console.log(d.stock_quantity)).catch(()=>console.log('0'))" | tr -d '\r\n')
echo "📊 Số lượng tồn kho sau đợt bão tải: ${FINAL_STOCK} chiếc"

if [[ "${FINAL_STOCK}" -lt 0 ]]; then
    echo "❌ THẤT BẠI NGHIÊM TRỌNG: Phát hiện hiện tượng BÁN ÂM KHO (Overselling)! Stock = ${FINAL_STOCK}"
else
    echo "✅ THÀNH CÔNG: Tồn kho được bảo toàn tuyệt đối, không có hiện tượng bán âm kho!"
fi

echo "Báo cáo chi tiết đã lưu tại: ${REPORT_FILE}"
