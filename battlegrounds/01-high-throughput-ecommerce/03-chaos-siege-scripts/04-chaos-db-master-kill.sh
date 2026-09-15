#!/usr/bin/env bash
# ============================================================================
# KỊCH BẢN 4: TRẢM TƯỚNG CẦM QUÂN - POSTGRESQL PRIMARY CRASH & FAILOVER DRILL
# Battleground 01: High-Throughput E-Commerce Core
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_URL="${TARGET_URL:-http://localhost:8080}"

echo "============================================================================"
echo "💥 [RED TEAM SIEGE] KHỞI ĐỘNG KỊCH BẢN 4: POSTGRESQL PRIMARY SIGKILL DRILL"
echo "============================================================================"

# 1. Đếm số đơn hàng hiện tại trong DB
echo "[Step 1] Kiểm tra số đơn hàng hiện có trong Primary..."
INITIAL_ORDERS=$(docker exec -i ecommerce-pg-primary psql -U postgres -d ecommerce -t -c \
    "SELECT count(*) FROM orders;" | tr -d ' ' || echo "0")
echo "📊 Số lượng đơn hàng trong DB trước khi phá: ${INITIAL_ORDERS}"

# 2. Bắt đầu bơm tải ghi đơn hàng liên tục
echo "[Step 2] Bơm luồng tải ghi đơn hàng liên tục (Background)..."
docker run --rm -d --name k6-write-siege \
    --network="host" \
    grafana/k6 run -e TARGET_URL="${TARGET_URL}" - <<'EOF'
import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  scenarios: {
    write_load: {
      executor: 'constant-arrival-rate',
      rate: 500,
      timeUnit: '1s',
      duration: '30s',
      preAllocatedVUs: 50,
    },
  },
};

export default function () {
  const userId = `chaos_usr_${__VU}_${__ITER}`;
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

sleep 8

# 3. TIÊM LỖI CHÍ MẠNG: BẮN KILL -9 VÀO POSTGRESQL PRIMARY
echo "🔥 [CHAOS INJECTION] BẮN LỆNH SIGKILL (-9) VÀO POSTGRESQL PRIMARY GIỮA ĐỈNH TẢI..."
START_CRASH_TIME=$(date +%s)
docker kill -s 9 ecommerce-pg-primary

echo "Đang theo dõi sự gián đoạn của dịch vụ và Worker..."
sleep 10

# 4. Kiểm tra Standby Replica còn sống và dữ liệu dừng ở đâu
echo "[Step 3] Kiểm tra Standby Replica (Port 5435)..."
REPLICA_ORDERS=$(docker exec -i ecommerce-pg-replica psql -U postgres -d ecommerce -t -c \
    "SELECT count(*) FROM orders;" | tr -d ' ' || echo "0")
echo "📊 Số lượng đơn hàng đã kịp replicate sang Standby: ${REPLICA_ORDERS}"

# 5. Phục hồi Primary
echo "[Step 4] Khởi động lại PostgreSQL Primary (Simulate Auto-Healing/Failover)..."
docker start ecommerce-pg-primary
sleep 8
END_RECOVER_TIME=$(date +%s)
DOWNTIME=$((END_RECOVER_TIME - START_CRASH_TIME))

docker stop k6-write-siege || true

FINAL_ORDERS=$(docker exec -i ecommerce-pg-primary psql -U postgres -d ecommerce -t -c \
    "SELECT count(*) FROM orders;" | tr -d ' ' || echo "0")

echo "============================================================================"
echo "🎯 ĐÁNH GIÁ SRE DOWNTIME VÀ THẤT THOÁT DỮ LIỆU (RTO & RPO SCORECARD)"
echo "============================================================================"
echo "⏱️ Thời gian gián đoạn Database (Write RTO): ~${DOWNTIME} giây"
echo "📊 Tổng đơn hàng trong DB sau khi phục hồi: ${FINAL_ORDERS}"
echo "✅ Kịch bản 4 hoàn thành!"
