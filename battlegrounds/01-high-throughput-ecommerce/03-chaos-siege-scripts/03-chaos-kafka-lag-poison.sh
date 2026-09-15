#!/usr/bin/env bash
# ============================================================================
# KỊCH BẢN 3: TẮC NGHẼN HÀNG ĐỢI & DỮ LIỆU ĐỘC HẠI (KAFKA LAG & POISON PILL)
# Battleground 01: High-Throughput E-Commerce Core
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_URL="${TARGET_URL:-http://localhost:8080}"
KAFKA_CONTAINER="ecommerce-kafka"
TOPIC="orders.events"
GROUP_ID="order-processing-group"

echo "============================================================================"
echo "💀 [RED TEAM SIEGE] KHỞI ĐỘNG KỊCH BẢN 3: KAFKA LAG & POISON PILL INJECTION"
echo "============================================================================"

# 1. Đóng băng Worker (Simulate Worker Hang / Network Partition)
echo "[Step 1] Đóng băng Worker Container (docker pause)..."
docker pause ecommerce-order-worker

# 2. Bơm 500 đơn hàng hợp lệ để tạo Lag
echo "[Step 2] Bơm 500 đơn hàng qua Order API vào Kafka..."
for i in {1..500}; do
    curl -s -X POST "${TARGET_URL}/api/v1/orders" \
        -H "Content-Type: application/json" \
        -d "{\"product_id\":\"prod_macbook_m3\",\"quantity\":1,\"user_id\":\"user_${i}\"}" > /dev/null &
done
wait
echo "✅ Đã bơm 500 orders vào Kafka."

# 3. TIÊM POISON PILL (DỮ LIỆU ĐỘC HẠI / MALFORMED JSON)
echo "🔥 [Step 3] TIÊM 3 MESSAGE ĐỘC HẠI VÀO TOPIC '${TOPIC}'..."
# Poison 1: Corrupted JSON
echo '{"corrupt_json": true, missing_bracket' | \
    docker exec -i "${KAFKA_CONTAINER}" /opt/kafka/bin/kafka-console-producer.sh \
        --bootstrap-server localhost:9092 --topic "${TOPIC}" || true

# Poison 2: Thiếu trường bắt buộc (Missing required schema fields)
echo '{"unexpected_field": 999999}' | \
    docker exec -i "${KAFKA_CONTAINER}" /opt/kafka/bin/kafka-console-producer.sh \
        --bootstrap-server localhost:9092 --topic "${TOPIC}" || true

# Poison 3: Null bytes
echo -e 'POISON_BINARY_\x00\xFF_ATTACK' | \
    docker exec -i "${KAFKA_CONTAINER}" /opt/kafka/bin/kafka-console-producer.sh \
        --bootstrap-server localhost:9092 --topic "${TOPIC}" || true

echo "✅ Đã tiêm xong 3 Poison Pill messages."

# 4. Kiểm tra Consumer Lag
echo "[Step 4] Kiểm tra Consumer Lag trên Kafka Broker:"
docker exec -i "${KAFKA_CONTAINER}" /opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 \
    --describe --group "${GROUP_ID}" || true

# 5. Phục hồi Worker và kiểm tra phản ứng chống độc
echo "[Step 5] Đánh thức Worker dậy (docker unpause)..."
docker unpause ecommerce-order-worker
sleep 5

echo "[Step 6] Kiểm tra trạng thái Worker (Liệu có bị CrashLoop do Poison Pill?):"
docker ps --filter "name=ecommerce-order-worker" --format "table {{.Names}}\t{{.Status}}"
echo "--- Nhật ký log của Worker khi nuốt phải Poison Pill ---"
docker logs --tail 25 ecommerce-order-worker

echo "============================================================================"
echo "✅ Kịch bản 3 hoàn thành!"
echo "============================================================================"
