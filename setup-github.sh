#!/usr/bin/env bash
# ============================================================
# setup-github.sh — Apply branch protection, environments,
#                   and repo settings via GitHub CLI (gh)
#
# Requires: gh cli authenticated, OWNER_USERNAME set
# Called by bootstrap.sh — can also be run standalone
# ============================================================
set -euo pipefail

REPO="${1:?Usage: setup-github.sh <owner/repo> <owner-username>}"
OWNER_USERNAME="${2:?Provide your GitHub username as second argument}"

C_BOLD='\033[1m'; C_GREEN='\033[92m'; C_RESET='\033[0m'
ok() { echo -e "${C_GREEN}✓${C_RESET} $*"; }

echo ""
echo -e "${C_BOLD}Configuring GitHub: $REPO${C_RESET}"
echo ""

# ── Branch protection: main ──────────────────────────────────────────────────
# - Requires PR + review
# - You (OWNER_USERNAME) are always required reviewer via CODEOWNERS
# - Blocks direct pushes (only release/* and hotfix/* can merge via PR)
# - Requires all CI checks to pass
# - Enforces linear history (no merge commits on main)

echo "Setting branch protection: main"
gh api "repos/$REPO/branches/main/protection" \
  --method PUT \
  --header "Accept: application/vnd.github+json" \
  --field required_status_checks='{"strict":true,"contexts":["lint","test","sast","dependency-scan","secrets-scan","build"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"require_code_owner_reviews":true,"dismiss_stale_reviews":true}' \
  --field restrictions=null \
  --field required_linear_history=true \
  --field allow_force_pushes=false \
  --field allow_deletions=false \
  > /dev/null
ok "main: PR required, CODEOWNERS review required, linear history enforced"

# ── Branch protection: develop ───────────────────────────────────────────────
# Less strict than main — requires CI but not mandatory code owner review

echo "Setting branch protection: develop"
gh api "repos/$REPO/branches/develop/protection" \
  --method PUT \
  --header "Accept: application/vnd.github+json" \
  --field required_status_checks='{"strict":true,"contexts":["lint","test","sast","secrets-scan"]}' \
  --field enforce_admins=false \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --field restrictions=null \
  --field allow_force_pushes=false \
  > /dev/null
ok "develop: PR required, 1 reviewer, CI gates"

# ── GitHub Environment: production ──────────────────────────────────────────
# This is the gate that requires YOUR approval before any production deploy

echo "Creating environment: production"
gh api "repos/$REPO/environments/production" \
  --method PUT \
  --header "Accept: application/vnd.github+json" \
  --field wait_timer=0 \
  > /dev/null

# Add you as required reviewer
OWNER_ID=$(gh api "users/$OWNER_USERNAME" --jq '.id')
gh api "repos/$REPO/environments/production" \
  --method PUT \
  --header "Accept: application/vnd.github+json" \
  --field "reviewers[][type]=User" \
  --field "reviewers[][id]=$OWNER_ID" \
  > /dev/null
ok "production environment: $OWNER_USERNAME set as required approver"

# ── GitHub Environment: staging ──────────────────────────────────────────────
echo "Creating environment: staging"
gh api "repos/$REPO/environments/staging" \
  --method PUT \
  --header "Accept: application/vnd.github+json" \
  > /dev/null
ok "staging environment: auto-deploy (no approval gate)"

# ── Repo settings ────────────────────────────────────────────────────────────
echo "Applying repo settings"
gh api "repos/$REPO" \
  --method PATCH \
  --header "Accept: application/vnd.github+json" \
  --field delete_branch_on_merge=true \
  --field allow_merge_commit=false \
  --field allow_squash_merge=true \
  --field allow_rebase_merge=false \
  --field squash_merge_commit_title="PR_TITLE" \
  --field squash_merge_commit_message="PR_BODY" \
  > /dev/null
ok "Squash-only merges, delete branch on merge"

echo ""
echo -e "${C_BOLD}GitHub setup complete.${C_RESET}"
echo ""
echo "Summary:"
echo "  main      → PR required + CODEOWNERS ($OWNER_USERNAME) + all CI green"
echo "  develop   → PR required + 1 reviewer + CI green"
echo "  prod env  → Manual approval by $OWNER_USERNAME before every deploy"
echo "  staging   → Auto-deploy on push to develop/release/*"
echo ""
