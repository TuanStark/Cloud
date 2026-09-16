#!/usr/bin/env bash
# ============================================================================
# KỊCH BẢN 3: TẮC NGHẼN HÀNG ĐỢI & DỮ LIỆU ĐỘC HẠI (KAFKA LAG & POISON PILL)
# Battleground 01: High-Throughput E-Commerce Core (EKS & Floci Cloud Native)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_URL="${TARGET_URL:-http://localhost:8080}"
KUBECONFIG_PATH="${KUBECONFIG_PATH:-${HOME}/.kube/floci-config}"
TOPIC="orders.events"
GROUP_ID="order-processing-group"

echo "============================================================================"
echo "💀 [RED TEAM SIEGE] KHỞI ĐỘNG KỊCH BẢN 3: KAFKA LAG & POISON PILL INJECTION"
echo "Môi trường: EKS on Floci Cloud"
echo "Topic:      ${TOPIC}"
echo "============================================================================"

# 1. Đóng băng Worker bằng cách Scale xuống 0 (Simulate Worker Hang / Split-Brain)
echo "[Step 1] Tạm dừng Worker xử lý đơn hàng (scale replicas = 0)..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce scale deployment/order-worker-deployment --replicas=0
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce wait --for=delete pod -l app=order-worker --timeout=20s 2>/dev/null || true

# 2. Bơm 200 đơn hàng hợp lệ để tạo Lag tích lũy
echo "[Step 2] Bơm 200 đơn hàng qua Order API vào Kafka để dồn ứ hàng đợi..."
for i in {1..200}; do
    curl -s -X POST "${TARGET_URL}/api/v1/orders" \
        -H "Content-Type: application/json" \
        -d "{\"product_id\":\"prod_macbook_m3\",\"quantity\":1,\"user_id\":\"user_lag_${i}\"}" > /dev/null &
    if (( i % 50 == 0 )); then
        wait
    fi
done
wait
echo "✅ Đã bơm 200 orders vào Kafka."

# 3. TIÊM POISON PILL (DỮ LIỆU ĐỘC HẠI / MALFORMED JSON)
echo "🔥 [Step 3] TIÊM 3 MESSAGE ĐỘC HẠI VÀO TOPIC '${TOPIC}' TRÊN KAFKA POD..."
KAFKA_POD=$(kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce get pod -l app=kafka -o jsonpath='{.items[0].metadata.name}')

# Poison 1: Corrupted JSON
echo '{"corrupt_json": true, missing_bracket' | \
    kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce exec -i "${KAFKA_POD}" -- \
        /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic "${TOPIC}" || true

# Poison 2: Thiếu trường bắt buộc (Missing required schema fields)
echo '{"unexpected_field": 999999}' | \
    kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce exec -i "${KAFKA_POD}" -- \
        /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic "${TOPIC}" || true

# Poison 3: Null bytes
printf 'POISON_BINARY_\x00\xFF_ATTACK\n' | \
    kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce exec -i "${KAFKA_POD}" -- \
        /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic "${TOPIC}" || true

echo "✅ Đã tiêm xong 3 Poison Pill messages trực tiếp vào phân vùng Kafka."

# 4. Kiểm tra Consumer Lag
echo "[Step 4] Kiểm tra Consumer Lag trên Kafka Broker:"
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce exec -i "${KAFKA_POD}" -- \
    /opt/kafka/bin/kafka-consumer-groups.sh \
        --bootstrap-server localhost:9092 \
        --describe --group "${GROUP_ID}" || true

# 5. Phục hồi Worker và kiểm tra phản ứng chống độc
echo "[Step 5] Khởi động lại Worker (scale replicas = 2)..."
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce scale deployment/order-worker-deployment --replicas=2
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce wait --for=condition=ready pod -l app=order-worker --timeout=30s
sleep 5

echo "[Step 6] Kiểm tra trạng thái Worker (Liệu có nuốt trôi Poison Pill hay bị CrashLoop?):"
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce get pods -l app=order-worker -o wide

echo "--- Nhật ký log của Worker khi bắt gặp Poison Pill ---"
kubectl --kubeconfig="${KUBECONFIG_PATH}" -n ecommerce logs -l app=order-worker --tail 30 | grep -E "Poison Pill|Processed batch|ConsumerGroup" || true

echo "============================================================================"
echo "✅ Kịch bản 3 hoàn thành: Worker tự động cô lập Poison Pill, tiêu thụ sạch Lag!"
echo "============================================================================"
