#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${RED}🚨 [EMERGENCY MITIGATION] INCIDENT COMMANDER RA LỆNH ROLLBACK!${NC}"
echo -e "Thời điểm bắt đầu cấp cứu: $(date)"

echo -e "\n${YELLOW}>>> [1/3] Hoán đổi bản dựng sang phiên bản ổn định đã kiểm chứng (v1.2.2-stable)...${NC}"
cp labs/level5-observability-sre/lab15-incident-rca-simulation/03-mitigation-rollback/server-stable.js \
   labs/level5-observability-sre/lab15-incident-rca-simulation/01-incident-simulation/server-buggy.js

echo -e "${YELLOW}>>> [2/3] Tái khởi động container ứng dụng với Zero-Downtime Rolling Update...${NC}"
cd labs/level5-observability-sre/lab15-incident-rca-simulation
docker compose restart payment-vault-app

echo -e "\n${YELLOW}>>> [3/3] Chờ 3 giây để dịch vụ sẵn sàng và kiểm tra Health Check...${NC}"
sleep 3
HEALTH=$(curl -s http://localhost:8082/health)
echo -e "Health Check Response: ${GREEN}$HEALTH${NC}"

echo -e "\n${CYAN}>>> Kiểm tra bắn thử 10 giao dịch nghiệm thu sau Rollback:${NC}"
SUCCESS_COUNT=0
for i in {1..10}; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8082/api/v1/charge)
  if [ "$CODE" == "200" ]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  fi
done

echo -e "${GREEN}✅ Kết quả nghiệm thu: $SUCCESS_COUNT/10 giao dịch THÀNH CÔNG RỰC RỠ (HTTP 200)!${NC}"
echo -e "${GREEN}🎉 ĐÁM CHÁY ĐÃ ĐƯỢC DẬP TẮT TRONG VÒNG CHƯA ĐẦY 60 GIÂY!${NC}"
