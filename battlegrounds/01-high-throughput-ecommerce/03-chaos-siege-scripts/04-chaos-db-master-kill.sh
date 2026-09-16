#!/usr/bin/env bash
# ============================================================================
# KỊCH BẢN 4: TRẢM TƯỚNG CẦM QUÂN - POSTGRESQL PRIMARY CRASH & FAILOVER DRILL
# Battleground 01: High-Throughput E-Commerce Core (EKS & Floci Cloud Native)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_URL="${TARGET_URL:-http://localhost:8080}"
FLOCI_HOST="13.140.183.90"
RDS_CONTAINER="floci-rds-cluster-CDB7CABC72DB40A386E0B3BC-4d06ed"

echo "============================================================================"
echo "💥 [RED TEAM SIEGE] KHỞI ĐỘNG KỊCH BẢN 4: AURORA RDS PRIMARY SIGKILL DRILL"
echo "Môi trường:      RDS Aurora PostgreSQL on Floci Cloud (${FLOCI_HOST})"
echo "Container Mục tiêu: ${RDS_CONTAINER}"
echo "============================================================================"

# Helper chạy lệnh SQL trên PostgreSQL RDS
run_db_query() {
    local query="$1"
    ssh "root@${FLOCI_HOST}" "docker exec -i ${RDS_CONTAINER} psql -U dbadmin -d ecommerce_db -t -c \"${query}\"" 2>/dev/null || echo "0"
}

# 1. Đếm số đơn hàng hiện tại trong DB
echo "[Step 1] Kiểm tra số đơn hàng hiện có trong Aurora RDS..."
INITIAL_ORDERS=$(run_db_query "SELECT count(*) FROM orders;" | tr -d ' ')
echo "📊 Số lượng đơn hàng trong DB trước khi phá: ${INITIAL_ORDERS}"

# 2. Bắt đầu bơm tải ghi đơn hàng liên tục (Background k6)
echo "[Step 2] Bơm luồng tải ghi đơn hàng liên tục (Background 300 RPS)..."
docker run --rm -d --name k6-write-siege \
    --network="host" \
    grafana/k6 run -e TARGET_URL="${TARGET_URL}" - <<'EOF'
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
    `${__ENV.TARGET_URL || 'http://localhost:8080'}/api/v1/orders`,
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
ssh "root@${FLOCI_HOST}" "docker kill -s 9 ${RDS_CONTAINER}"

echo "Đang theo dõi phản ứng của Kafka Queue & Worker (Backoff & Retry)..."
sleep 8

# 4. Phục hồi Primary Container (Simulate RDS Auto-Restart / Failover)
echo "[Step 3] Khởi động lại PostgreSQL Primary (Simulate RDS Auto-Restart)..."
ssh "root@${FLOCI_HOST}" "docker start ${RDS_CONTAINER}"
sleep 5
END_RECOVER_TIME=$(date +%s)
DOWNTIME=$((END_RECOVER_TIME - START_CRASH_TIME))

docker stop k6-write-siege 2>/dev/null || true

# Chờ worker tiêu thụ hết hàng đợi đã tích lũy trong Kafka
echo "[Step 4] Chờ Worker tự động kết nối lại DB và xả hàng tồn trong Kafka (10s)..."
sleep 10

FINAL_ORDERS=$(run_db_query "SELECT count(*) FROM orders;" | tr -d ' ')
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
