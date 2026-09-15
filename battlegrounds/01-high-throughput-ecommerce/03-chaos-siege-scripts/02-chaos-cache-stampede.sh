#!/usr/bin/env bash
# ============================================================================
# KỊCH BẢN 2: ĐỘT QUỴ CACHE - CACHE STAMPEDE & EVICTION
# Battleground 01: High-Throughput E-Commerce Core
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_URL="${TARGET_URL:-http://localhost:8080}"
REPORT_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORT_DIR}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/cache_stampede_${TIMESTAMP}.txt"

echo "============================================================================"
echo "⚡ [RED TEAM SIEGE] KHỞI ĐỘNG KỊCH BẢN 2: CACHE STAMPEDE (REDIS KILL DRILL)"
echo "Target Endpoint: ${TARGET_URL}"
echo "Báo cáo: ${REPORT_FILE}"
echo "============================================================================"

# 1. Đo lường kết nối DB trước khi phá
echo "[Step 1] Đo số kết nối active trên PostgreSQL Primary..."
docker exec -i ecommerce-pg-primary psql -U postgres -d ecommerce -c \
    "SELECT count(*) as initial_db_connections FROM pg_stat_activity WHERE state = 'active';" || true

# 2. Khởi chạy tải nền 3,000 RPS bằng k6 trong background
echo "[Step 2] Bơm lưu lượng đọc tồn kho 3,000 RPS trong background..."
docker run --rm -d --name k6-background-runner \
    --network="host" \
    grafana/k6 run -e TARGET_URL="${TARGET_URL}" - <<'EOF'
import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  scenarios: {
    constant_load: {
      executor: 'constant-arrival-rate',
      rate: 3000,
      timeUnit: '1s',
      duration: '40s',
      preAllocatedVUs: 200,
    },
  },
};

export default function () {
  http.get(`${__ENV.TARGET_URL || 'http://localhost:8080'}/api/v1/products/prod_macbook_m3`);
}
EOF

echo "Đang chờ tải đạt đỉnh (10s)..."
sleep 10

# 3. TIÊM LỖI: BẮN CHẾT CONTAINER REDIS (SIMULATE SUDDEN CRASH)
echo "🔥 [CHAOS INJECTION] TIẾN HÀNH BẮN HẠ CONTAINER REDIS NGAY GIỮA ĐỈNH TẢI..."
docker stop ecommerce-redis

echo "Đang theo dõi phản ứng của hệ thống (Dogpile Effect)..."
sleep 10

# 4. Kiểm tra sức ép lên PostgreSQL (Connections Spike)
echo "[Step 3] Kiểm tra số kết nối dồn xuống PostgreSQL khi không còn Cache..."
docker exec -i ecommerce-pg-primary psql -U postgres -d ecommerce -c \
    "SELECT count(*) as spike_db_connections FROM pg_stat_activity WHERE state = 'active';" || true

# 5. Phục hồi Redis
echo "[Step 4] Khởi động lại Redis (Simulate SRE Recovery)..."
docker start ecommerce-redis
sleep 5

echo "Dọn dẹp tải nền..."
docker stop k6-background-runner || true

echo "============================================================================"
echo "✅ Kịch bản 2 hoàn thành! Kiểm tra log và metric để ghi nhận Breaking Point."
echo "============================================================================"
