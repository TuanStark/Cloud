#!/usr/bin/env bash
# =========================================================================
# 🤝 CI/CD HANDSHAKE AUTOMATION SCRIPT
# =========================================================================
# Simulates the CI pipeline updating Helm values after image scan passed.
# Author: Le Cong Tuan <tuanstark>
# =========================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHART_DIR="${LAB_DIR}/helm-chart"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

NEW_TAG="${1:-1.2.1}"
TARGET_ENV="${2:-dev}"

echo -e "${CYAN}${BOLD}"
echo "================================================================================"
echo "          🤝 CI/CD HANDSHAKE: UPDATING GITOPS MANIFEST WITH NEW IMAGE TAG        "
echo "================================================================================"
echo -e "${NC}"

echo -e "Target Environment: ${BOLD}${TARGET_ENV^^}${NC}"
echo -e "New Image Tag:      ${BOLD}payment-vault-api:${NEW_TAG}${NC}\n"

# Cập nhật AppVersion trong Chart.yaml
sed -i "s/appVersion: .*/appVersion: \"${NEW_TAG}\"/" "${CHART_DIR}/Chart.yaml"
echo -e "${GREEN}✅ Updated Chart.yaml appVersion to ${NEW_TAG}${NC}"

# Cập nhật tag trong values.yaml
sed -i "s/tag: .*/tag: \"${NEW_TAG}\"/" "${CHART_DIR}/values.yaml"
echo -e "${GREEN}✅ Updated values.yaml image.tag to ${NEW_TAG}${NC}"

echo -e "\n${YELLOW}>>> Verifying Helm Template render with new image tag:${NC}"
helm template test-release "${CHART_DIR}" -f "${CHART_DIR}/values-${TARGET_ENV}.yaml" | grep "image:"

echo -e "\n${GREEN}${BOLD}🎉 HANDSHAKE COMPLETE!${NC}"
echo -e "In GitHub Actions CI, the runner will execute:"
echo -e "${CYAN}git commit -am \"ci(release): deploy payment-vault-api:${NEW_TAG} to ${TARGET_ENV} [skip ci]\" && git push origin main${NC}\n"
