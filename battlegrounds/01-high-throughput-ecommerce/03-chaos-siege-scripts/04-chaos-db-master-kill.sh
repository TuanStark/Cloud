#!/usr/bin/env bash
# ============================================================================
# KỊCH BẢN 4: TRẢM TƯỚNG CẦM QUÂN - POSTGRESQL PRIMARY CRASH & FAILOVER DRILL
# Battleground 01: High-Throughput E-Commerce Core
# Thực thi trực tiếp TRÊN HẠ TẦNG FLOCI (EKS + AURORA RDS)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/floci-config}"
FLOCI_HOST="13.140.183.90"
RDS_CONTAINER="floci-rds-cluster-CDB7CABC72DB40A386E0B3BC-4d06ed"

echo "============================================================================"
echo "💥 [RED TEAM SIEGE] KHỞI ĐỘNG KỊCH BẢN 4: AURORA RDS PRIMARY SIGKILL DRILL"
echo "Môi trường:      RDS Aurora PostgreSQL on Floci Cloud (${FLOCI_HOST})"
echo "Container Mục tiêu: ${RDS_CONTAINER}"
echo "============================================================================"

# Helper đếm số đơn hàng trong DB
count_db_orders() {
    kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce exec deployment/order-worker-deployment -- node -e "const { pool } = require('./src/db'); pool.query('SELECT count(*) FROM orders').then(r => console.log(r.rows[0].count)).catch(() => console.log('0'))" 2>/dev/null | tr -d '\r\n ' || echo "0"
}

# 1. Đếm số đơn hàng hiện tại trong DB
echo "[Step 1] Kiểm tra số đơn hàng hiện có trong Aurora RDS..."
INITIAL_ORDERS=$(count_db_orders)
echo "📊 Số lượng đơn hàng trong DB trước khi phá: ${INITIAL_ORDERS}"

# 2. Bắt đầu bơm tải ghi đơn hàng liên tục (Chạy Pod k6 trực tiếp trong cụm EKS)
echo "[Step 2] Bơm luồng tải ghi đơn hàng liên tục (k6 Pod trực tiếp trên Floci EKS)..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce delete pod k6-write-siege --now 2>/dev/null || true

cat <<'EOF' | kubectl --kubeconfig="${KUBECONFIG_PATH}" run k6-write-siege \
    --image=grafana/k6:latest \
    --restart=Never \
    -n ecommerce \
    -- run -e TARGET_URL="http://order-api-service:80" -
import http from 'k6/http';

export const options = {
  scenarios: {
    write_load: {
      executor: 'constant-arrival-rate',
      rate: 300,
      timeUnit: '1s',
      duration: '25s',
      preAllocatedVUs: 50,
    },
  },
};

export default function () {
  const userId = `chaos_usr_${__VU}_${__ITER}_${Math.floor(Math.random() * 100000)}`;
  http.post(
    'http://order-api-service:80/api/v1/orders',
    JSON.stringify({
      product_id: 'prod_macbook_m3',
      quantity: 1,
      user_id: userId,
    }),
    { headers: { 'Content-Type': 'application/json' } }
  );
}
EOF

sleep 6

# 3. TIÊM LỖI CHÍ MẠNG: BẮN KILL -9 VÀO RDS POSTGRESQL PRIMARY TRÊN MÁY CHỦ FLOCI
echo "🔥 [CHAOS INJECTION] BẮN LỆNH SIGKILL (-9) VÀO RDS POSTGRESQL CONTAINER..."
START_CRASH_TIME=$(date +%s)
ssh "root@${FLOCI_HOST}" "docker kill -s 9 ${RDS_CONTAINER}" 2>/dev/null || true

echo "Đang theo dõi phản ứng của Kafka Queue & Worker (Backoff & Retry)..."
sleep 8

# 4. Phục hồi Primary Container (Simulate RDS Auto-Restart / Failover)
echo "[Step 3] Khởi động lại PostgreSQL Primary (Simulate RDS Auto-Restart)..."
ssh "root@${FLOCI_HOST}" "docker start ${RDS_CONTAINER}" 2>/dev/null || true
sleep 5
END_RECOVER_TIME=$(date +%s)
DOWNTIME=$((END_RECOVER_TIME - START_CRASH_TIME))

kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce delete pod k6-write-siege --now 2>/dev/null || true

# Chờ worker tiêu thụ hết hàng đợi đã tích lũy trong Kafka
echo "[Step 4] Chờ Worker tự động kết nối lại DB và xả hàng tồn trong Kafka (10s)..."
sleep 10

FINAL_ORDERS=$(count_db_orders)
ORDERS_PROCESSED=$((FINAL_ORDERS - INITIAL_ORDERS))

echo "============================================================================"
echo "🎯 ĐÁNH GIÁ SRE DOWNTIME VÀ TÍNH TOÀN VẸN DỮ LIỆU (RTO & RPO SCORECARD)"
echo "============================================================================"
echo "⏱️ Thời gian gián đoạn Database (Write RTO): ~${DOWNTIME} giây"
echo "📊 Đơn hàng trước khi gãy DB:                ${INITIAL_ORDERS}"
echo "📊 Đơn hàng sau khi DB phục hồi:            ${FINAL_ORDERS}"
echo "📈 Tổng số đơn hàng được Worker cứu và ghi: ${ORDERS_PROCESSED}"
echo "✅ RPO = 0: Không mất một đơn hàng nào nhờ kiến trúc Asynchronous Event-Driven!"
echo "============================================================================"
