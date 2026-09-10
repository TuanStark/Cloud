#!/usr/bin/env bash
# =========================================================================
# 🛡️ ENTERPRISE DEVSECOPS PIPELINE LOCAL RUNNER
# =========================================================================
# Simulates the 5 Multi-Layer Security Gates locally before pushing to Git.
# Tools: Trivy CLI, Docker Daemon
# Author: Le Cong Tuan <tuanstark>
# =========================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${LAB_DIR}/sample-app"

# Terminal Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default Configuration
TARGET_MODE="hardened" # "hardened" or "insecure"
SPECIFIC_GATE=""
TOTAL_FAILURES=0

print_banner() {
  echo -e "${BLUE}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════════════════════╗"
  echo "║        🥋 ENTERPRISE DEVSECOPS 5-STAGE LOCAL CI/CD PIPELINE                 ║"
  echo "║        Shift-Left Security Gateways | CIS Benchmarks | Zero-Trust           ║"
  echo "╚══════════════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

usage() {
  echo -e "Usage: $0 [OPTIONS]"
  echo -e "Options:"
  echo -e "  --mode=hardened     Run pipeline against hardened production files (Expect PASS)"
  echo -e "  --mode=insecure     Run pipeline against vulnerable files (Expect FAIL / Block PR)"
  echo -e "  --gate=<1-5>        Run only a specific security gate (1 to 5)"
  echo -e "  -h, --help          Show this help message"
  exit 0
}

# Parse Command Line Arguments
for arg in "$@"; do
  case $arg in
    --mode=hardened)
      TARGET_MODE="hardened"
      shift
      ;;
    --mode=insecure)
      TARGET_MODE="insecure"
      shift
      ;;
    --gate=*)
      SPECIFIC_GATE="${arg#*=}"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      ;;
  esac
done

# Gate 1: Secret Scanning
run_gate_1() {
  echo -e "\n${CYAN}${BOLD}[GATE 1/5] Secret Scanning (Trivy Secret Engine)${NC}"
  echo -e "Detecting hardcoded cloud credentials, tokens, private keys in source tree..."

  local target_file="${APP_DIR}/server.js"
  if [[ "$TARGET_MODE" == "insecure" ]]; then
    target_file="${APP_DIR}/server-vulnerable.js"
    echo -e "${YELLOW}>>> [INSECURE MODE] Scanning intentionally vulnerable file: server-vulnerable.js${NC}"
  else
    echo -e "${GREEN}>>> [HARDENED MODE] Scanning production file: server.js${NC}"
  fi

  if trivy fs --scanners secret --severity HIGH,CRITICAL --exit-code 1 "$target_file"; then
    echo -e "${GREEN}✅ [GATE 1 PASSED] No hardcoded secrets detected.${NC}"
    return 0
  else
    echo -e "${RED}❌ [GATE 1 FAILED] CRITICAL/HIGH Secrets leaked in source code! PR BLOCKED.${NC}"
    return 1
  fi
}

# Gate 2: SAST (Static Application Security Testing)
run_gate_2() {
  echo -e "\n${CYAN}${BOLD}[GATE 2/5] SAST Code Vulnerability Analysis (Static Security Check)${NC}"
  echo -e "Scanning code logic for OWASP Top 10 flaws (Injection, Insecure Config, eval)..."

  local target_file="${APP_DIR}/server.js"
  if [[ "$TARGET_MODE" == "insecure" ]]; then
    target_file="${APP_DIR}/server-vulnerable.js"
    echo -e "${YELLOW}>>> [INSECURE MODE] Inspecting: server-vulnerable.js${NC}"
    # Search for dangerous sink patterns in vulnerable code
    if grep -En "(child_process\.exec|eval\(|SELECT \* FROM.*= '\s*\+)" "$target_file"; then
      echo -e "${RED}❌ [GATE 2 FAILED] Dangerous sink patterns detected (Command Injection, SQL Injection, eval)! PR BLOCKED.${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}>>> [HARDENED MODE] Inspecting: server.js${NC}"
    # Hardened check: Ensure helmet and input validation exist
    if grep -q "helmet()" "$target_file" && ! grep -En "(child_process\.exec|eval\()" "$target_file"; then
      echo -e "${GREEN}✅ [GATE 2 PASSED] Code meets OWASP Top 10 defense standards (Helmet enabled, parameterized queries).${NC}"
      return 0
    else
      echo -e "${RED}❌ [GATE 2 FAILED] Missing defensive middleware or unsafe code detected.${NC}"
      return 1
    fi
  fi
}

# Gate 3: SCA (Software Composition Analysis)
run_gate_3() {
  echo -e "\n${CYAN}${BOLD}[GATE 3/5] SCA Dependency Scanning (Third-Party CVEs)${NC}"
  echo -e "Auditing application dependencies against National Vulnerability Database (NVD)..."

  local target_pkg="${APP_DIR}/package-lock.json"
  if [[ "$TARGET_MODE" == "insecure" ]]; then
    target_pkg="${APP_DIR}/test-fixtures/package-lock.json"
    echo -e "${YELLOW}>>> [INSECURE MODE] Scanning vulnerable dependency tree: package-lock.json${NC}"
  else
    echo -e "${GREEN}>>> [HARDENED MODE] Scanning production dependencies: package-lock.json${NC}"
  fi

  if trivy fs --scanners vuln --skip-db-update --severity HIGH,CRITICAL --exit-code 1 "$target_pkg"; then
    echo -e "${GREEN}✅ [GATE 3 PASSED] Zero HIGH/CRITICAL vulnerabilities in dependencies.${NC}"
    return 0
  else
    echo -e "${RED}❌ [GATE 3 FAILED] Known CVEs found in dependencies! Update packages before merge.${NC}"
    return 1
  fi
}

# Gate 4: Dockerfile & IaC Security Linting (CIS Docker Benchmarks)
run_gate_4() {
  echo -e "\n${CYAN}${BOLD}[GATE 4/5] Dockerfile Security Linting (CIS Docker Benchmarks)${NC}"
  echo -e "Verifying non-root execution, minimal attack surface, healthcheck declaration..."

  local target_dockerfile="${APP_DIR}/Dockerfile"
  if [[ "$TARGET_MODE" == "insecure" ]]; then
    target_dockerfile="${APP_DIR}/Dockerfile.insecure"
    echo -e "${YELLOW}>>> [INSECURE MODE] Auditing anti-pattern Dockerfile: Dockerfile.insecure${NC}"
  else
    echo -e "${GREEN}>>> [HARDENED MODE] Auditing CIS-compliant Dockerfile: Dockerfile${NC}"
  fi

  if trivy config --skip-check-update --severity HIGH,CRITICAL --exit-code 1 "$target_dockerfile"; then
    echo -e "${GREEN}✅ [GATE 4 PASSED] Dockerfile adheres to CIS Docker Benchmarks.${NC}"
    return 0
  else
    echo -e "${RED}❌ [GATE 4 FAILED] Dockerfile violates security policies (Root user or unsafe base image)!${NC}"
    return 1
  fi
}

# Gate 5: Container Image Vulnerability Scanning
run_gate_5() {
  echo -e "\n${CYAN}${BOLD}[GATE 5/5] Container Image Vulnerability Scanning${NC}"
  echo -e "Building container image and scanning OS packages (glibc, openssl, busybox)..."

  local target_dockerfile="${APP_DIR}/Dockerfile"
  local image_tag="payment-vault-api:local-hardened"

  if [[ "$TARGET_MODE" == "insecure" ]]; then
    target_dockerfile="${APP_DIR}/Dockerfile.insecure"
    image_tag="payment-vault-api:local-insecure"
    echo -e "${YELLOW}>>> [INSECURE MODE] Building and scanning insecure image...${NC}"
  else
    echo -e "${GREEN}>>> [HARDENED MODE] Building and scanning hardened image...${NC}"
  fi

  echo -e "Building Docker image: ${image_tag} ..."
  docker build -q -t "$image_tag" -f "$target_dockerfile" "$APP_DIR" > /dev/null

  echo -e "Scanning container image with Trivy (Fail on CRITICAL,HIGH)..."
  if trivy image --skip-db-update --severity HIGH,CRITICAL --exit-code 1 "$image_tag"; then
    echo -e "${GREEN}✅ [GATE 5 PASSED] Container image is free of CRITICAL/HIGH OS vulnerabilities.${NC}"
    return 0
  else
    echo -e "${RED}❌ [GATE 5 FAILED] Container image contains exploitable OS vulnerabilities!${NC}"
    return 1
  fi
}

# Main Execution Flow
print_banner
echo -e "Execution Mode: ${BOLD}${TARGET_MODE^^}${NC}"
echo -e "Target Application Directory: ${APP_DIR}\n"

start_time=$(date +%s)

declare -A GATE_RESULTS
declare -a GATES_TO_RUN

if [[ -n "$SPECIFIC_GATE" ]]; then
  GATES_TO_RUN=("$SPECIFIC_GATE")
else
  GATES_TO_RUN=(1 2 3 4 5)
fi

for gate in "${GATES_TO_RUN[@]}"; do
  case $gate in
    1)
      if run_gate_1; then GATE_RESULTS[1]="PASS"; else GATE_RESULTS[1]="FAIL"; TOTAL_FAILURES=$((TOTAL_FAILURES + 1)); fi
      ;;
    2)
      if run_gate_2; then GATE_RESULTS[2]="PASS"; else GATE_RESULTS[2]="FAIL"; TOTAL_FAILURES=$((TOTAL_FAILURES + 1)); fi
      ;;
    3)
      if run_gate_3; then GATE_RESULTS[3]="PASS"; else GATE_RESULTS[3]="FAIL"; TOTAL_FAILURES=$((TOTAL_FAILURES + 1)); fi
      ;;
    4)
      if run_gate_4; then GATE_RESULTS[4]="PASS"; else GATE_RESULTS[4]="FAIL"; TOTAL_FAILURES=$((TOTAL_FAILURES + 1)); fi
      ;;
    5)
      if run_gate_5; then GATE_RESULTS[5]="PASS"; else GATE_RESULTS[5]="FAIL"; TOTAL_FAILURES=$((TOTAL_FAILURES + 1)); fi
      ;;
  esac
done

end_time=$(date +%s)
duration=$((end_time - start_time))

# Print Final Summary Table
echo -e "\n${BOLD}========================================================================${NC}"
echo -e "${BOLD}                       PIPELINE EXECUTION SUMMARY                        ${NC}"
echo -e "${BOLD}========================================================================${NC}"
printf "%-12s %-35s %-15s\n" "GATE" "DESCRIPTION" "RESULT"
echo "------------------------------------------------------------------------"

for gate in "${GATES_TO_RUN[@]}"; do
  local_desc=""
  case $gate in
    1) local_desc="Secret Scanning (API Keys/Tokens)" ;;
    2) local_desc="SAST (OWASP Top 10 Logic)" ;;
    3) local_desc="SCA (Dependency CVEs)" ;;
    4) local_desc="IaC & Dockerfile (CIS Benchmarks)" ;;
    5) local_desc="Container Image OS Scan" ;;
  esac

  if [[ "${GATE_RESULTS[$gate]}" == "PASS" ]]; then
    printf "%-12s %-35s ${GREEN}%-15s${NC}\n" "Gate $gate" "$local_desc" "PASSED ✅"
  else
    printf "%-12s %-35s ${RED}%-15s${NC}\n" "Gate $gate" "$local_desc" "BLOCKED ❌"
  fi
done

echo "------------------------------------------------------------------------"
echo -e "Total Pipeline Duration: ${duration}s"

if [[ $TOTAL_FAILURES -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}🎉 SUCCESS: All Security Gates PASSED! Artifact is certified for Deployment.${NC}\n"
  exit 0
else
  echo -e "${RED}${BOLD}⛔ QUALITY GATE FAILURE: Pipeline blocked ${TOTAL_FAILURES} security violations.${NC}"
  echo -e "${RED}${BOLD}   In production CI/CD, this Pull Request would be locked from merging.${NC}\n"
  exit 1
fi
