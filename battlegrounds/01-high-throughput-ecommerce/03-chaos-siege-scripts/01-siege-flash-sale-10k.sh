#!/usr/bin/env bash
# ============================================================================
# KỊCH BẢN 1: CƠN BÃO FLASH SALE 10,000 RPS (RED TEAM SIEGE)
# Battleground 01: High-Throughput E-Commerce Core
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_URL="${TARGET_URL:-http://localhost:8080}"
REPORT_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORT_DIR}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/flash_sale_10k_${TIMESTAMP}.txt"

echo "============================================================================"
echo "🔥 [RED TEAM SIEGE] KHỞI ĐỘNG KỊCH BẢN 1: FLASH SALE 10,000 RPS"
echo "Target Endpoint: ${TARGET_URL}/api/v1/orders"
echo "Báo cáo xuất tại: ${REPORT_FILE}"
echo "============================================================================"

# 1. Kiểm tra Liveness Endpoint trước khi bắn
echo "[Step 1] Kiểm tra sức khỏe hệ thống..."
if ! curl -sf "${TARGET_URL}/healthz" > /dev/null; then
    echo "❌ Lỗi: Target URL không phản hồi hoặc hệ thống chưa sẵn sàng!"
    exit 1
fi
echo "✅ Hệ thống đang sẵn sàng (Liveness check passed)."

# 2. Kiểm tra tồn kho trước giờ G
echo "[Step 2] Kiểm tra tồn kho khởi tạo..."
INITIAL_STOCK=$(curl -s "${TARGET_URL}/api/v1/products/prod_macbook_m3" | grep -o '"stock_quantity":[0-9]*' | cut -d':' -f2 || echo "N/A")
echo "📊 Số lượng tồn kho ban đầu: ${INITIAL_STOCK} chiếc"

# 3. Khai hỏa k6
echo "[Step 3] Khai hỏa k6 container bắn phá..."
docker run --rm -i \
    --network="host" \
    -v "${SCRIPT_DIR}/k6-flash-sale-10k.js:/scripts/test.js:ro" \
    -e TARGET_URL="${TARGET_URL}" \
    grafana/k6 run /scripts/test.js 2>&1 | tee "${REPORT_FILE}"

echo "============================================================================"
echo "🎯 ĐÁNH GIÁ KẾT QUẢ VÀ TÍNH TOÀN VẸN TỒN KHO (OVERSELLING AUDIT)"
echo "============================================================================"
FINAL_STOCK=$(curl -s "${TARGET_URL}/api/v1/products/prod_macbook_m3" | grep -o '"stock_quantity":[0-9]*' | cut -d':' -f2 || echo "0")
echo "📊 Số lượng tồn kho sau đợt bão tải: ${FINAL_STOCK} chiếc"

if [[ "${FINAL_STOCK}" -lt 0 ]]; then
    echo "❌ THẤT BẠI NGHIÊM TRỌNG: Phát hiện hiện tượng BÁN ÂM KHO (Overselling)! Stock = ${FINAL_STOCK}"
else
    echo "✅ THÀNH CÔNG: Tồn kho được bảo toàn tuyệt đối, không có hiện tượng bán âm kho!"
fi

echo "Báo cáo chi tiết đã lưu tại: ${REPORT_FILE}"
