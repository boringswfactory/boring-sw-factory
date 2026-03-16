#!/usr/bin/env bash
# ============================================================
# publish.sh — Create or update the boring-sw-factory repo on GitHub
#              and mark it as a Template Repository.
#
# Run once from your local clone of this factory:
#   ./scripts/publish.sh [org-or-username]
# ============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FACTORY_CONFIG="$HOME/.config/boring-sw-factory/env"

C_BOLD='\033[1m'; C_GREEN='\033[92m'; C_RESET='\033[0m'
ok() { echo -e "${C_GREEN}✓${C_RESET}  $*"; }

# Load config or use arg
# shellcheck source=/dev/null
if [[ -f "$FACTORY_CONFIG" ]]; then source "$FACTORY_CONFIG"; fi
TARGET_ORG="${1:-${FACTORY_ORG:-${FACTORY_OWNER:-""}}}"

if [[ -z "$TARGET_ORG" ]]; then
  read -rp "GitHub org or username to publish under: " TARGET_ORG
fi

REPO_FULL="$TARGET_ORG/boring-sw-factory"

echo ""
echo -e "${C_BOLD}Publishing: https://github.com/$REPO_FULL${C_RESET}"
echo ""

# Create repo if it doesn't exist
if gh repo view "$REPO_FULL" &>/dev/null; then
  ok "Repo already exists: $REPO_FULL"
else
  gh repo create "$REPO_FULL" \
    --private \
    --description "Multi-agent software factory — Claude Code + Gitflow + security-by-default" \
    --clone=false
  ok "Repo created: $REPO_FULL"
fi

# Push current code
cd "$REPO_ROOT"
git remote set-url origin "https://github.com/$REPO_FULL.git" 2>/dev/null \
  || git remote add origin "https://github.com/$REPO_FULL.git"

git push origin main --force-with-lease --quiet 2>/dev/null \
  || git push origin HEAD:main --quiet
ok "Code pushed to main"

# Mark as Template Repository (the key step)
gh api "repos/$REPO_FULL" \
  --method PATCH \
  --header "Accept: application/vnd.github+json" \
  --field is_template=true \
  > /dev/null
ok "Marked as GitHub Template Repository ✓"

# Recommended: protect main in the factory repo itself
gh api "repos/$REPO_FULL/branches/main/protection" \
  --method PUT \
  --header "Accept: application/vnd.github+json" \
  --field required_status_checks='{"strict":true,"contexts":["validate"]}' \
  --field enforce_admins=false \
  --field required_pull_request_reviews='{"required_approving_review_count":1}' \
  --field restrictions=null \
  > /dev/null
ok "main branch protected (PR + CI green)"

echo ""
echo -e "${C_BOLD}Done. Factory is live.${C_RESET}"
echo ""
echo "  Template URL:  https://github.com/$REPO_FULL"
echo "  Use button:    github.com/$REPO_FULL → 'Use this template'"
echo ""
echo "  Or via CLI:"
echo -e "  \033[94mgh repo create my-org/my-project \\"
echo -e "    --template $REPO_FULL \\"
echo -e "    --private --clone\033[0m"
echo -e "  \033[94mcd my-project && ./bootstrap.sh\033[0m"
echo ""
