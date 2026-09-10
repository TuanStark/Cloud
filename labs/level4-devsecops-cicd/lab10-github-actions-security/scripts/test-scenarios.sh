#!/usr/bin/env bash
# =========================================================================
# 🧪 DEVSECOPS CHAOS & REMEDIATION TEST SCENARIOS
# =========================================================================
# Demonstrates 4 real-world security violations blocked by our pipeline,
# followed by the hardened remediation passing all 5 gates.
# Author: Le Cong Tuan <tuanstark>
# =========================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_RUNNER="${SCRIPT_DIR}/run-pipeline-local.sh"

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
echo "================================================================================"
echo "          DEVSECOPS SECURITY GATES: 4 CHAOS SCENARIOS & REMEDIATION             "
echo "================================================================================"
echo -e "${NC}"

echo -e "${YELLOW}${BOLD}🔥 [SCENARIO 1/4] DEVELOPER ACCIDENTALLY COMMITS CLOUD & STRIPE SECRETS${NC}"
echo -e "Testing Gate 1 (Secret Scanning) against server-vulnerable.js..."
echo -e "Expected: Pipeline MUST FAIL (Exit 1) and identify leaked tokens.\n"
if ! "${PIPELINE_RUNNER}" --gate=1 --mode=insecure; then
  echo -e "\n${GREEN}>>> [VERIFIED] Gate 1 successfully caught and blocked leaked secrets!${NC}\n"
else
  echo -e "\n${RED}>>> [UNEXPECTED] Gate 1 failed to block leaked secrets!${NC}\n"
fi

read -rp "Press [Enter] to run Scenario 2 (SAST Code Vulnerabilities)..."

echo -e "\n${YELLOW}${BOLD}🔥 [SCENARIO 2/4] DEVELOPER WRITES INJECTION CODE (SQLi & COMMAND EXEC)${NC}"
echo -e "Testing Gate 2 (SAST Analysis) against server-vulnerable.js..."
echo -e "Expected: Pipeline MUST FAIL (Exit 1) and identify dangerous injection sinks.\n"
if ! "${PIPELINE_RUNNER}" --gate=2 --mode=insecure; then
  echo -e "\n${GREEN}>>> [VERIFIED] Gate 2 successfully caught and blocked injection vulnerabilities!${NC}\n"
else
  echo -e "\n${RED}>>> [UNEXPECTED] Gate 2 failed to block injection code!${NC}\n"
fi

read -rp "Press [Enter] to run Scenario 3 (SCA Supply Chain CVEs)..."

echo -e "\n${YELLOW}${BOLD}🔥 [SCENARIO 3/4] SUPPLY CHAIN ATTACK: VULNERABLE NPM DEPENDENCIES (CVEs)${NC}"
echo -e "Testing Gate 3 (SCA Dependency Scanner) against package-lock.json with CVEs..."
echo -e "Expected: Pipeline MUST FAIL (Exit 1) and list CVEs (lodash, jsonwebtoken).\n"
if ! "${PIPELINE_RUNNER}" --gate=3 --mode=insecure; then
  echo -e "\n${GREEN}>>> [VERIFIED] Gate 3 successfully caught and blocked vulnerable dependencies!${NC}\n"
else
  echo -e "\n${RED}>>> [UNEXPECTED] Gate 3 failed to block vulnerable packages!${NC}\n"
fi

read -rp "Press [Enter] to run Scenario 4 (CIS Dockerfile Violations)..."

echo -e "\n${YELLOW}${BOLD}🔥 [SCENARIO 4/4] INSECURE DOCKERFILE: RUNNING AS ROOT USER${NC}"
echo -e "Testing Gate 4 (Dockerfile Linting) against Dockerfile.insecure..."
echo -e "Expected: Pipeline MUST FAIL (Exit 1) due to CIS Docker Benchmark violations.\n"
if ! "${PIPELINE_RUNNER}" --gate=4 --mode=insecure; then
  echo -e "\n${GREEN}>>> [VERIFIED] Gate 4 successfully caught root user and unpinned tags!${NC}\n"
else
  echo -e "\n${RED}>>> [UNEXPECTED] Gate 4 failed to catch Dockerfile violations!${NC}\n"
fi

read -rp "Press [Enter] to run the Final Hardened Production Pipeline..."

echo -e "\n${GREEN}${BOLD}🛡️ [FINAL REMEDIATION] RUNNING FULL HARDENED PIPELINE (ALL 5 GATES)${NC}"
echo -e "Testing all 5 Gates against production-ready hardened application..."
echo -e "Expected: ALL 5 GATES MUST PASS (Exit 0)!\n"
"${PIPELINE_RUNNER}" --mode=hardened
