#!/usr/bin/env bash
# ============================================================================
# MASTER ATTACK RUNNER - RED TEAM CHAOS SIEGE SUITE
# Battleground 01: High-Throughput E-Commerce Core Engine (Flash Sale 10,000 RPS)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

chmod +x "${SCRIPT_DIR}"/*.sh

cat <<'BANNER'
============================================================================
⚔️ ENTERPRISE BATTLEGROUND 01 - RED TEAM CHAOS SIEGE SUITE
🎯 TARGET: High-Throughput E-Commerce & Fintech Core Engine (10,000 RPS)
============================================================================
Vui lòng chọn kịch bản bắn phá thực chiến:

1) Kịch bản 1: Cơn bão Flash Sale 10,000 RPS (Ramping VUs, Overselling Audit)
2) Kịch bản 2: Đột quỵ Cache (Cache Stampede & Redis Kill Drill)
3) Kịch bản 3: Tắc nghẽn hàng đợi & Dữ liệu độc hại (Kafka Lag & Poison Pill)
4) Kịch bản 4: Trảm tướng cầm quân (PostgreSQL Primary SIGKILL & Failover)
5) Khai hỏa toàn bộ 4 kịch bản theo chuỗi (Full Chaos Warfare)
q) Thoát
BANNER

read -rp "Nhập lựa chọn [1-5 / q]: " CHOICE

case "${CHOICE}" in
    1)
        "${SCRIPT_DIR}/01-siege-flash-sale-10k.sh"
        ;;
    2)
        "${SCRIPT_DIR}/02-chaos-cache-stampede.sh"
        ;;
    3)
        "${SCRIPT_DIR}/03-chaos-kafka-lag-poison.sh"
        ;;
    4)
        "${SCRIPT_DIR}/04-chaos-db-master-kill.sh"
        ;;
    5)
        echo "🔥 KHỞI ĐỘNG CHIẾN DỊCH BẮN PHÁ TOÀN DIỆN..."
        "${SCRIPT_DIR}/01-siege-flash-sale-10k.sh"
        sleep 5
        "${SCRIPT_DIR}/02-chaos-cache-stampede.sh"
        sleep 5
        "${SCRIPT_DIR}/03-chaos-kafka-lag-poison.sh"
        sleep 5
        "${SCRIPT_DIR}/04-chaos-db-master-kill.sh"
        echo "🏆 CHIẾN DỊCH BẮN PHÁ TOÀN DIỆN HOÀN TẤT!"
        ;;
    q|Q)
        echo "Thoát chương trình."
        exit 0
        ;;
    *)
        echo "Lựa chọn không hợp lệ!"
        exit 1
        ;;
esac
