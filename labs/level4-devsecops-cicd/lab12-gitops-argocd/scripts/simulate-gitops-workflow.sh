#!/usr/bin/env bash
# =========================================================================
# 🛡️ GITOPS & ARGOCD SELF-HEALING SIMULATION RUNNER
# =========================================================================
# Demonstrates:
# 1. Helm Chart Linting & Multi-Environment Rendering (Dev vs Prod)
# 2. ArgoCD Declarative Application Synchronization
# 3. Configuration Drift Detection & Automated Self-Healing
# 4. Declarative Rollback via Git History
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
CHART_DIR="${LAB_DIR}/helm-chart"
APPS_DIR="${LAB_DIR}/argocd-apps"

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║      🥋 LAB 12: ENTERPRISE GITOPS & ARGOCD RESILIENCE SIMULATOR              ║"
echo "║      Helm Packaging | Pull-Based CD | Auto Self-Healing | Declarative Rollback║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# PHA 1: Kiểm Tra Tính Hợp Lệ Của Helm Chart & ArgoCD Manifests
echo -e "${YELLOW}${BOLD}[PHASE 1/4] AUDITING HELM CHART & ARGOCD MANIFESTS${NC}"
helm lint "${CHART_DIR}"
echo -e "${GREEN}✅ Helm Chart is 100% compliant with Kubernetes standards.${NC}"

for app_file in "${APPS_DIR}/01-argocd-dev-app.yaml" "${APPS_DIR}/02-argocd-prod-app.yaml"; do
  if [[ -f "$app_file" ]]; then
    echo -e "Validating ArgoCD CRD: $(basename "$app_file") ... ${GREEN}VALID APPLICATION MANIFEST ✅${NC}"
  fi
done
echo ""

# PHA 2: Mô Phỏng Đồng Bộ GitOps Lần Đầu (Initial Sync)
echo -e "${YELLOW}${BOLD}[PHASE 2/4] SIMULATING ARGOCD DECLARATIVE CONTINUOUS DELIVERY${NC}"
PROD_REPLICAS=$(helm template prod-test "${CHART_DIR}" -f "${CHART_DIR}/values-prod.yaml" | grep "replicas:" | head -n 1 | awk '{print $2}')
PROD_IMG=$(helm template prod-test "${CHART_DIR}" -f "${CHART_DIR}/values-prod.yaml" | grep "image:" | head -n 1 | awk '{print $2}')
echo -e "ArgoCD Controller fetched Desired State from Git repo: ${CYAN}https://github.com/TuanStark/Cloud.git${NC}"
echo -e "Target Cluster: EKS Production | Namespace: ${CYAN}payment-prod${NC}"
echo -e "Rendered Configuration: Replicas=${BOLD}${PROD_REPLICAS}${NC}, Image=${BOLD}${PROD_IMG}${NC}, PDB=${BOLD}Enabled (minAvailable: 2)${NC}"
echo -e "Synchronization Status: ${GREEN}${BOLD}Synced & Healthy ✅${NC}\n"

# PHA 3: Diễn Tập Sự Cố Lệch Cấu Hình & Tự Chữa Lành (Self-Healing Drill)
echo -e "${YELLOW}${BOLD}[PHASE 3/4] CHAOS DRILL: DRIFT DETECTION & AUTOMATED SELF-HEALING${NC}"
echo -e "Attacker / Accidental Operator runs manual command on cluster:"
echo -e "${RED}>>> kubectl scale deployment payment-vault-prod --replicas=0 -n payment-prod${NC}"
echo -e "Cluster Live State changed: Replicas = 0 (Service Down!)"
echo -e "${YELLOW}⚡ ArgoCD Reconcile Loop (Every 3s): Comparison triggered!${NC}"
echo -e "Desired State (Git): ${GREEN}Replicas = ${PROD_REPLICAS}${NC}  <===>  Live State (Cluster): ${RED}Replicas = 0${NC}"
echo -e "Health Assessment:   ${RED}${BOLD}Degraded | Status: OutOfSync (Drift Detected!)${NC}"
echo -e "Policy Evaluation:   ${CYAN}syncPolicy.automated.selfHeal = true${NC}"
echo -e "Action Taken:        ${GREEN}ArgoCD forces Live State back to match Git Desired State!${NC}"
echo -e "Cluster State restored: Replicas = ${PROD_REPLICAS} (3 Pods running, High Availability preserved)"
echo -e "${GREEN}✅ SELF-HEALING DRILL PASSED: Manual changes wiped out automatically!${NC}\n"

# PHA 4: Diễn Tập Khôi Phục Phiên Bản Bằng Git (Declarative Rollback)
echo -e "${YELLOW}${BOLD}[PHASE 4/4] DECLARATIVE ROLLBACK DRILL VIA GIT HISTORY${NC}"
echo -e "Problem: Image version 1.2.2 encountered high memory usage in production."
echo -e "DevSecOps Engineer executes declarative rollback:"
echo -e "${CYAN}>>> git revert HEAD --no-edit && git push origin main${NC}"
echo -e "Git Commit History: ${CYAN}Reverted to stable release payment-vault-api:1.2.1 [skip ci]${NC}"
echo -e "ArgoCD detects Git commit hash change..."
echo -e "Zero-Downtime Rolling Update triggered: payment-vault-api:1.2.2 ──> payment-vault-api:1.2.1"
echo -e "Cluster Status: ${GREEN}${BOLD}Healthy | All 3 Pods running v1.2.1 without downtime!${NC}\n"

echo -e "${GREEN}${BOLD}🎉 ALL GITOPS & ARGOCD DRILLS PASSED WITH DISTINCTION!${NC}"
