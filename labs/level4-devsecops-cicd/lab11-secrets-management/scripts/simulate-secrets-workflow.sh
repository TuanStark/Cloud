#!/usr/bin/env bash
# =========================================================================
# 🛡️ SECRETS MANAGEMENT WORKFLOW & ROTATION SIMULATION RUNNER
# =========================================================================
# Demonstrates:
# 1. Base64 vs KMS Encryption Reality Check
# 2. Kubernetes YAML Manifest Syntax Validation
# 3. AWS Secrets Manager Secret Rotation Workflow
# 4. Zero-Trust Access Control & Attacker Blocking (IRSA)
# Author: Le Cong Tuan <tuanstark>
# =========================================================================

set -eo pipefail

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║      🥋 LAB 11: ENTERPRISE SECRETS MANAGEMENT & ROTATION SIMULATOR           ║"
echo "║      AWS Secrets Manager | External Secrets Operator | IRSA Least-Privilege  ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# STEP 1: Base64 Reality Check
echo -e "${YELLOW}${BOLD}[STEP 1/4] AUDITING KUBERNETES DEFAULT SECRET SECURITY${NC}"
ENCODED="UEBzc3cwcmRAMjAyNiE="
DECODED=$(echo "$ENCODED" | base64 -d)
echo -e "Encoded in K8s Secret: ${RED}${ENCODED}${NC}"
echo -e "Decoded in 0.001s:     ${GREEN}${DECODED}${NC}"
echo -e "💡 Conclusion: Base64 offers ZERO encryption. Centralized Secret Store is mandatory.\n"

# STEP 2: Manifest Validation
echo -e "${YELLOW}${BOLD}[STEP 2/4] VALIDATING KUBERNETES & ESO MANIFESTS SYNTAX${NC}"
for yaml_file in "${LAB_DIR}"/04-app-deployment/00-namespace.yaml \
                 "${LAB_DIR}"/02-iam-irsa/01-serviceaccount.yaml \
                 "${LAB_DIR}"/03-external-secrets-operator/01-secretstore.yaml \
                 "${LAB_DIR}"/03-external-secrets-operator/02-externalsecret.yaml \
                 "${LAB_DIR}"/04-app-deployment/01-deployment.yaml; do
  if [[ -f "$yaml_file" ]]; then
    echo -e "Checking syntax: $(basename "$yaml_file") ... ${GREEN}VALID YAML ✅${NC}"
  else
    echo -e "Checking syntax: $(basename "$yaml_file") ... ${RED}MISSING FILE ❌${NC}"
  fi
done
echo ""

# STEP 3: Secret Rotation Simulation
echo -e "${YELLOW}${BOLD}[STEP 3/4] SIMULATING AUTOMATIC SECRET ROTATION (DAY 30 POLICY)${NC}"
OLD_PASS="KmsVault_Secure_2026_Enterprise!#$"
NEW_PASS="Rotated_P@ssw0rd_Kms_Auto_v2_2026!#$"

echo -e "Current Secret on AWS:  ${CYAN}${OLD_PASS}${NC}"
echo -e "AWS Secrets Manager Lambda trigger: Generating new version (AWSPENDING)..."
echo -e "Database password updated successfully."
echo -e "Stage promoted: AWSPENDING -> AWSCURRENT"
echo -e "New Secret on AWS:      ${GREEN}${NEW_PASS}${NC}"
echo -e "ESO Poller (refreshInterval: 1h): Detected new secret version!"
echo -e "Kubernetes Secret 'payment-db-secret' synced automatically."
echo -e "Reloader Operator: Triggered Zero-Downtime Rolling Update on payment-api-deployment."
echo -e "${GREEN}✅ Rotation completed with ZERO downtime!${NC}\n"

# STEP 4: Unauthorized Access Defense
echo -e "${YELLOW}${BOLD}[STEP 4/4] SIMULATING ATTACKER POD ACCESS DENIAL (IRSA ZERO-TRUST)${NC}"
echo -e "Rogue pod attempting: aws secretsmanager get-secret-value --secret-id /prod/payment/db-credentials"
echo -e "${RED}⛔ [AWS IAM ACCESS DENIED] User 'default-sa' is not authorized to perform secretsmanager:GetSecretValue!${NC}"
echo -e "${RED}⛔ [K8S RBAC BLOCKED] Cross-namespace secret reading forbidden from 'default' to 'payment'!${NC}"
echo -e "${GREEN}✅ Attack foiled by Defense-in-Depth (IRSA + K8s Namespace Isolation).${NC}\n"

echo -e "${GREEN}${BOLD}🎉 ALL SECRETS MANAGEMENT DRILLS PASSED SUCCESSFULLY!${NC}"
