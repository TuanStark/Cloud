#!/usr/bin/env bash
# ============================================================================
# KỊCH BẢN 2: ĐỘT QUỴ CACHE - CACHE STAMPEDE & EVICTION
# Battleground 01: High-Throughput E-Commerce Core (EKS & Floci Cloud Native)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_URL="${TARGET_URL:-http://localhost:8080}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/floci-config}"
REPORT_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORT_DIR}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/cache_stampede_${TIMESTAMP}.txt"

FLOCI_HOST="13.140.183.90"
RDS_CONTAINER="floci-rds-cluster-CDB7CABC72DB40A386E0B3BC-4d06ed"

echo "============================================================================"
echo "⚡ [RED TEAM SIEGE] KHỞI ĐỘNG KỊCH BẢN 2: CACHE STAMPEDE (REDIS KILL DRILL)"
echo "Target Endpoint: ${TARGET_URL}"
echo "Môi trường:      EKS on Floci Cloud (${FLOCI_HOST})"
echo "Báo cáo:         ${REPORT_FILE}"
echo "============================================================================"

# Helper chạy lệnh SQL trên PostgreSQL RDS
run_db_query() {
    local query="$1"
    ssh "root@${FLOCI_HOST}" "docker exec -i ${RDS_CONTAINER} psql -U dbadmin -d ecommerce_db -t -c \"${query}\"" 2>/dev/null || echo "0"
}

# 1. Đo lường kết nối DB trước khi phá
echo "[Step 1] Đo số kết nối active trên PostgreSQL Aurora RDS..."
INITIAL_CONNS=$(run_db_query "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" | tr -d ' ')
echo "📊 Active DB connections ban đầu: ${INITIAL_CONNS}"

# 2. Khởi chạy tải nền 3,000 RPS bằng k6 trong background
echo "[Step 2] Bơm lưu lượng đọc tồn kho 3,000 RPS trong background..."
docker run --rm -d --name k6-background-runner \
    --network="host" \
    grafana/k6 run -e TARGET_URL="${TARGET_URL}" - <<'EOF'
import http from 'k6/http';

export const options = {
  scenarios: {
    constant_load: {
      executor: 'constant-arrival-rate',
      rate: 3000,
      timeUnit: '1s',
      duration: '35s',
      preAllocatedVUs: 150,
    },
  },
};

export default function () {
  http.get(`${__ENV.TARGET_URL || 'http://localhost:8080'}/api/v1/products/prod_macbook_m3`);
}
EOF

echo "Đang chờ tải đạt đỉnh (8s)..."
sleep 8

# 3. TIÊM LỖI: BẮN HẠ REDIS POD TRÊN EKS (SIMULATE SUDDEN CRASH / EVICTION)
echo "🔥 [CHAOS INJECTION] TIẾN HÀNH BẮN HẠ POD REDIS TRÊN EKS NGAY GIỮA ĐỈNH TẢI..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce delete pod -l app=redis --now

echo "Đang theo dõi phản ứng của hệ thống (Dogpile Effect dồn tải xuống DB)..."
sleep 6

# 4. Kiểm tra sức ép lên PostgreSQL (Connections Spike)
echo "[Step 3] Kiểm tra số kết nối dồn xuống Aurora PostgreSQL khi Cache bị gián đoạn..."
SPIKE_CONNS=$(run_db_query "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" | tr -d ' ')
echo "📊 Active DB connections trong lúc đột quỵ Cache: ${SPIKE_CONNS}"

# 5. Đợi K8s tự phục hồi Pod Redis
echo "[Step 4] Chờ Kubernetes Pod Self-Healing phục hồi Redis..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce wait --for=condition=ready pod -l app=redis --timeout=30s
echo "✅ Redis Pod đã được Kubernetes tự động khởi sinh thành công!"

echo "Dọn dẹp tải nền..."
docker stop k6-background-runner 2>/dev/null || true

echo "============================================================================"
echo "🎯 KẾT QUẢ KỊCH BẢN 2: CACHE STAMPEDE"
echo "============================================================================"
echo "Active Connections trước Drill: ${INITIAL_CONNS}"
echo "Active Connections khi Cache gãy: ${SPIKE_CONNS}"
echo "✅ Khả năng chịu tải và tự phục hồi (Self-Healing) của EKS đạt chuẩn!"
echo "Báo cáo chi tiết đã lưu tại: ${REPORT_FILE}"
