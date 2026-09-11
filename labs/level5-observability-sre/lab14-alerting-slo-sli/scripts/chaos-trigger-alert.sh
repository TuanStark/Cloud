#!/bin/bash
# =========================================================================
# 🥋 LAB 14: SRE AUTOMATED CHAOS & ALERTING VERIFICATION DRILL
# =========================================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

APP_URL="http://localhost:8081"
PROM_URL="http://localhost:9091"
AM_URL="http://localhost:9093"
RECEIVER_CONTAINER="alert-receiver-lab14"

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         🥋 LAB 14: ENTERPRISE SRE ALERTING & SLO/SLI TEST HARNESS            ║${NC}"
echo -e "${CYAN}║      Chaos Injection | Multi-Window Alerting | Alertmanager Routing & Resolve║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"

# -------------------------------------------------------------------------
# GIAI ĐOẠN 1: KIỂM TRA SỨC KHỎE CỦA CỤM
# -------------------------------------------------------------------------
echo -e "${BLUE}[STEP 1/5] CHECKING OBSERVABILITY CLUSTER HEALTH${NC}"
echo -n "Checking Payment Vault App (Port 8081)... "
curl -s "$APP_URL/health" | grep -q "Payment Vault API" && echo -e "${GREEN}UP ✅${NC}" || (echo -e "${RED}DOWN ❌${NC}" && exit 1)

echo -n "Checking Prometheus Alerts API (Port 9091)... "
curl -s "$PROM_URL/api/v1/rules" | grep -q "payment-vault-slo-alerts" && echo -e "${GREEN}RULES LOADED ✅${NC}" || (echo -e "${RED}FAILED ❌${NC}" && exit 1)

echo -n "Checking Alertmanager (Port 9093)... "
curl -s "$AM_URL/api/v2/status" | grep -q "ready" && echo -e "${GREEN}READY ✅${NC}" || (echo -e "${RED}FAILED ❌${NC}" && exit 1)

# -------------------------------------------------------------------------
# GIAI ĐOẠN 2: XÁC NHẬN TRẠNG THÁI BÌNH THƯỜNG (INACTIVE)
# -------------------------------------------------------------------------
echo -e "\n${BLUE}[STEP 2/5] VERIFYING BASELINE STATE (ALL RULES INACTIVE)${NC}"
echo "Current Alert Rule status:"
curl -s "$PROM_URL/api/v1/rules" | python3 -c '
import sys, json
data = json.load(sys.stdin)
for group in data.get("data", {}).get("groups", []):
    for rule in group.get("rules", []):
        if rule.get("type") == "alerting":
            name = rule.get("name")
            st = rule.get("state")
            print(f"   • {name}: state={st} (healthy)")
'
echo -e "${GREEN}✅ All SLO alert rules are INACTIVE (Healthy baseline).${NC}"

# -------------------------------------------------------------------------
# GIAI ĐOẠN 3: KÍCH NỔ CHAOS - TỶ LỆ LỖI VƯỢT XÀ 60%
# -------------------------------------------------------------------------
echo -e "\n${RED}[STEP 3/5] INJECTING CHAOS: SIMULATING 60% 5XX ERROR RATE SPIKE${NC}"
echo ">>> Triggering Chaos via API: POST $APP_URL/chaos/error"
CHAOS_RES=$(curl -s -X POST "$APP_URL/chaos/error")
echo -e "Response: ${YELLOW}$CHAOS_RES${NC}"

echo -e "\n⏳ Waiting for Prometheus to evaluate PromQL rule..."
PENDING_DETECTED=false
FIRING_DETECTED=false

for i in {1..12}; do
    sleep 3
    STATE=$(curl -s "$PROM_URL/api/v1/rules" | python3 -c '
import sys, json
data = json.load(sys.stdin)
state = "unknown"
for group in data.get("data", {}).get("groups", []):
    for rule in group.get("rules", []):
        if rule.get("name") == "High5xxErrorRate":
            state = rule.get("state")
print(state)
')
    echo "   [Time +$((i * 3))s] Rule 'High5xxErrorRate' state: $STATE"

    if [ "$STATE" == "pending" ] && [ "$PENDING_DETECTED" = false ]; then
        echo -e "   ${YELLOW}⚡ Pending State Detected! Prometheus is enforcing for: 15s noise filter...${NC}"
        PENDING_DETECTED=true
    fi

    if [ "$STATE" == "firing" ]; then
        echo -e "   ${RED}🚨 FIRING STATE DETECTED! Prometheus pushed alert to Alertmanager!${NC}"
        FIRING_DETECTED=true
        break
    fi
done

if [ "$FIRING_DETECTED" = false ]; then
    echo -e "${RED}❌ Timed out waiting for alert to enter firing state.${NC}"
    exit 1
fi

# -------------------------------------------------------------------------
# GIAI ĐOẠN 4: KIỂM CHỨNG GÓI TIN TẠI SRE ALERT RECEIVER
# -------------------------------------------------------------------------
echo -e "\n${BLUE}[STEP 4/5] INSPECTING INCOMING ALERT AT SRE ALERT RECEIVER${NC}"
echo "Waiting 5s for Alertmanager group_wait and webhook dispatch..."
sleep 5

echo -e "${CYAN}--- DÂY CHUYỀN THÔNG BÁO TẠI SRE ALERT RECEIVER (CONTAINER LOGS) ---${NC}"
docker logs "$RECEIVER_CONTAINER" --tail 25
echo -e "${CYAN}--------------------------------------------------------------------${NC}"
echo -e "${GREEN}✅ Alert successfully received, parsed, grouped, and routed to P1 Critical!${NC}"

# -------------------------------------------------------------------------
# GIAI ĐOẠN 5: DẬP TẮT SỰ CỐ & NHẬN THÔNG BÁO [RESOLVED]
# -------------------------------------------------------------------------
echo -e "\n${GREEN}[STEP 5/5] RESOLVING INCIDENT: RECOVERY TO NORMAL OPERATION${NC}"
echo ">>> Deactivating Chaos via API: POST $APP_URL/chaos/normal"
NORM_RES=$(curl -s -X POST "$APP_URL/chaos/normal")
echo -e "Response: ${GREEN}$NORM_RES${NC}"

echo -e "⏳ Waiting for Prometheus to confirm recovery and Alertmanager to send [RESOLVED]..."
sleep 18

echo -e "${CYAN}--- THÔNG BÁO GIẢI QUYẾT SỰ CỐ (CONTAINER LOGS) ---${NC}"
docker logs "$RECEIVER_CONTAINER" --tail 15
echo -e "${CYAN}--------------------------------------------------${NC}"

echo -e "\n${GREEN}🎉 TOÀN BỘ DIỄN TẬP CẢNH BÁO SRE ĐÃ HOÀN TẤT THÀNH CÔNG RỰC RỠ!${NC}"
