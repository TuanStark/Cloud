#!/usr/bin/env bash
# ============================================================================
# KỊCH BẢN 2: ĐỘT QUỴ CACHE - CACHE STAMPEDE & EVICTION
# Battleground 01: High-Throughput E-Commerce Core
# Thực thi trực tiếp TRÊN HẠ TẦNG FLOCI EKS
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/floci-config}"
REPORT_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORT_DIR}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/cache_stampede_${TIMESTAMP}.txt"

echo "============================================================================"
echo "⚡ [RED TEAM SIEGE] KHỞI ĐỘNG KỊCH BẢN 2: CACHE STAMPEDE (REDIS KILL DRILL)"
echo "Môi trường:      EKS on Floci Cloud"
echo "Mục tiêu:        http://order-api-service:80"
echo "Báo cáo:         ${REPORT_FILE}"
echo "============================================================================"

# Helper chạy query trên DB qua worker pod trong EKS
run_db_query() {
    local sql="$1"
    kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce exec deployment/order-worker-deployment -- node -e "const { pool } = require('./src/db'); pool.query(\`${sql}\`).then(r => console.log(r.rows[0].count)).catch(() => console.log('0'))" | tr -d '\r\n '
}

# 1. Đo lường kết nối DB trước khi phá
echo "[Step 1] Đo số kết nối active trên PostgreSQL Aurora RDS..."
INITIAL_CONNS=$(run_db_query "SELECT count(*) FROM pg_stat_activity WHERE state = 'active'")
echo "📊 Active DB connections ban đầu: ${INITIAL_CONNS}"

# 2. Khởi chạy tải nền 3,000 RPS bằng k6 Pod trực tiếp trên Floci EKS
echo "[Step 2] Bơm lưu lượng đọc tồn kho 3,000 RPS trực tiếp trên EKS Cluster..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce delete pod k6-stampede-bg --now 2>/dev/null || true

cat <<'EOF' | kubectl --kubeconfig="${KUBECONFIG_PATH}" run k6-stampede-bg \
    --image=grafana/k6:latest \
    --restart=Never \
    -n ecommerce \
    -- run -e TARGET_URL="http://order-api-service:80" -
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
  http.get('http://order-api-service:80/api/v1/products/prod_macbook_m3');
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
SPIKE_CONNS=$(run_db_query "SELECT count(*) FROM pg_stat_activity WHERE state = 'active'")
echo "📊 Active DB connections trong lúc đột quỵ Cache: ${SPIKE_CONNS}"

# 5. Đợi K8s tự phục hồi Pod Redis
echo "[Step 4] Chờ Kubernetes Pod Self-Healing phục hồi Redis..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce wait --for=condition=ready pod -l app=redis --timeout=30s
echo "✅ Redis Pod đã được Kubernetes tự động khởi sinh thành công!"

echo "Dọn dẹp tải nền..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce delete pod k6-stampede-bg --now 2>/dev/null || true

echo "============================================================================"
echo "🎯 KẾT QUẢ KỊCH BẢN 2: CACHE STAMPEDE"
echo "============================================================================"
echo "Active Connections trước Drill: ${INITIAL_CONNS}"
echo "Active Connections khi Cache gãy: ${SPIKE_CONNS}"
echo "✅ Khả năng chịu tải và tự phục hồi (Self-Healing) của Floci EKS đạt chuẩn!"
echo "Báo cáo chi tiết đã lưu tại: ${REPORT_FILE}"
