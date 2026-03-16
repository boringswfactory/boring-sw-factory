#!/usr/bin/env bash
# ============================================================
# bootstrap.sh — Initialize a new project from the factory template
#
# Run this ONCE after creating a repo from the GitHub template:
#
#   gh repo create my-org/my-project --template my-org/boring-sw-factory --private --clone
#   cd my-project
#   ./bootstrap.sh
#
# What it does:
#   1. Reads config (~/.config/boring-sw-factory/env) or prompts once
#   2. Renames remote if needed, applies Gitflow branch structure
#   3. Applies project-templates/ into the repo root
#   4. Configures branch protection + production approval gate (gh cli)
#   5. Runs the multi-agent factory (factory.sh) → deliverables in docs/
#   6. Commits everything and prints next steps
#   7. Self-destructs factory internals from the project repo
# ============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_CONFIG="$HOME/.config/boring-sw-factory/env"

C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
C_GREEN='\033[92m'; C_YELLOW='\033[93m'; C_RED='\033[91m'; C_BLUE='\033[94m'

ok()     { echo -e "${C_GREEN}✓${C_RESET}  $*"; }
warn()   { echo -e "${C_YELLOW}!${C_RESET}  $*"; }
err()    { echo -e "${C_RED}✗${C_RESET}  $*" >&2; exit 1; }
header() { echo -e "\n${C_BOLD}── $* ──────────────────────────────────────────${C_RESET}\n"; }

# ── Dependency check ─────────────────────────────────────────
for cmd in gh git python3 claude; do
  command -v "$cmd" &>/dev/null || err "Missing: $cmd"
done
gh auth status &>/dev/null || err "gh not authenticated — run: gh auth login"

# ── Load or create config ─────────────────────────────────────
if [[ ! -f "$FACTORY_CONFIG" ]]; then
  echo ""
  echo -e "${C_BOLD}First-time setup${C_RESET} — saved to $FACTORY_CONFIG"
  echo ""
  read -rp "  Your GitHub username : " _OWNER
  read -rp "  Default GitHub org   : " _ORG
  _ORG="${_ORG:-$_OWNER}"
  mkdir -p "$(dirname "$FACTORY_CONFIG")"
  printf 'FACTORY_OWNER="%s"\nFACTORY_ORG="%s"\n' "$_OWNER" "$_ORG" > "$FACTORY_CONFIG"
  ok "Config saved"
fi
# shellcheck source=/dev/null
source "$FACTORY_CONFIG"

# ── Detect repo info from git remote ─────────────────────────
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -z "$REMOTE_URL" ]]; then
  err "No git remote 'origin' found. Is this a cloned repo?"
fi

# Extract org/repo from remote URL (https or ssh)
REPO_FULL=$(echo "$REMOTE_URL" \
  | sed -E 's|.*github\.com[:/]||; s|\.git$||')
PROJECT_NAME=$(basename "$REPO_FULL")

# ── Project brief ─────────────────────────────────────────────
echo ""
echo -e "${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_BOLD}  BORING SW FACTORY — Bootstrapping: $PROJECT_NAME${C_RESET}"
echo -e "${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo ""

if [[ $# -gt 0 && "$1" == "--brief-file" ]]; then
  PROJECT_BRIEF=$(cat "$2")
elif [[ $# -gt 0 && "$1" != --* ]]; then
  PROJECT_BRIEF="$*"
else
  echo -e "  Describe this project (requirements, constraints, tech, scale)."
  echo -e "  ${C_DIM}End with Ctrl+D on a new line.${C_RESET}"
  echo ""
  PROJECT_BRIEF=$(cat)
fi

echo ""
echo "$PROJECT_BRIEF" > "$REPO_ROOT/docs/brief.md"
ok "Brief saved → docs/brief.md"

# ── Step 1: Gitflow ───────────────────────────────────────────
header "1/5  Gitflow"

# Ensure main exists and is current
git checkout main --quiet 2>/dev/null || git checkout -b main --quiet

# Create develop if missing
if git ls-remote --exit-code origin develop &>/dev/null; then
  git checkout develop --quiet
  git pull origin develop --quiet
  warn "develop branch already exists — using it"
else
  git checkout -b develop --quiet
  git push -u origin develop --quiet
  ok "develop created and pushed"
fi

git checkout main --quiet
ok "Gitflow: main + develop ready"

# ── Step 2: Apply project templates ──────────────────────────
header "2/5  Project templates"

TMPL="$REPO_ROOT/project-templates"

# .github — workflows, CODEOWNERS, PR template
cp -r "$TMPL/.github" "$REPO_ROOT/"
sed -i.bak "s/@OWNER_GITHUB_USERNAME/@$FACTORY_OWNER/g" \
  "$REPO_ROOT/.github/CODEOWNERS" && rm "$REPO_ROOT/.github/CODEOWNERS.bak"
ok ".github/ (CI, CD staging, CD production, CODEOWNERS → @$FACTORY_OWNER, PR template)"

# docs structure
cp -r "$TMPL/docs/." "$REPO_ROOT/docs/"
ok "docs/ (ADR template, architecture structure)"

# .gitignore
cat >> "$REPO_ROOT/.gitignore" 2>/dev/null << 'EOF' || true

# environment
.env
.env.*
!.env.example
*.pem
*.key
secrets/
.DS_Store
EOF
ok ".gitignore updated"

# ── Step 3: GitHub settings ───────────────────────────────────
header "3/5  GitHub — branch protection & environments"

bash "$REPO_ROOT/scripts/setup-github.sh" "$REPO_FULL" "$FACTORY_OWNER"

# ── Step 4: Factory agents ────────────────────────────────────
header "4/5  Multi-agent factory"

bash "$REPO_ROOT/factory.sh" "$PROJECT_BRIEF"

# Pull latest generated project and copy deliverables into docs/
FACTORY_PROJECTS="$REPO_ROOT/projects"
LATEST=$(find "$FACTORY_PROJECTS" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

if [[ -n "$LATEST" ]]; then
  for team in backend frontend platform qa security docs; do
    SRC="$FACTORY_PROJECTS/$LATEST/$team/deliverable.md"
    if [[ -f "$SRC" ]]; then
      mkdir -p "$REPO_ROOT/docs/$team"
      cp "$SRC" "$REPO_ROOT/docs/$team/deliverable.md"
    fi
  done
  cp "$FACTORY_PROJECTS/$LATEST/plan.json" "$REPO_ROOT/docs/plan.json" 2>/dev/null || true
  ok "Deliverables copied → docs/"
fi

# ── Step 5: Commit and self-clean ────────────────────────────
header "5/5  Commit & cleanup"

# Remove factory internals from project repo — they live in the factory template
# The project only keeps .github/, docs/, scripts/, and its own code
ITEMS_TO_REMOVE=(
  "agents"
  "project-templates"
  "projects"
  "factory.sh"
  "review.sh"
  "bootstrap.sh"
  "CLAUDE.md"
  "scripts/setup-github.sh"
)

for item in "${ITEMS_TO_REMOVE[@]}"; do
  if [[ -e "$REPO_ROOT/$item" ]]; then
    git rm -rf "$REPO_ROOT/${item:?}" --quiet 2>/dev/null || rm -rf "$REPO_ROOT/${item:?}"
  fi
done

# Also remove scripts/ if now empty
rmdir "$REPO_ROOT/scripts" 2>/dev/null || true

ok "Factory internals removed from project repo"

# Commit on develop
git checkout develop --quiet
git add -A
git commit -m "chore: bootstrap project from boring-sw-factory template

- GitHub Actions: CI pipeline (lint, test, SAST, secrets, trivy)
- CD: staging (auto) + production (manual approval gate)
- Branch protection: main requires PR + @$FACTORY_OWNER + CI green
- Production environment: @$FACTORY_OWNER is required approver
- docs/: factory deliverables (architecture, security, QA, docs)
- ADR template and docs structure

Factory: https://github.com/$FACTORY_ORG/boring-sw-factory
[skip ci]" --quiet

git push origin develop --quiet
ok "Committed to develop"

# Sync main
git checkout main --quiet
git merge develop --no-edit --quiet
git push origin main --quiet
git checkout develop --quiet
ok "main synced"

# ── Done ──────────────────────────────────────────────────────
echo ""
echo -e "${C_BOLD}━━━ Project ready ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo ""
echo -e "  ${C_BOLD}Repo${C_RESET}     https://github.com/$REPO_FULL"
echo -e "  ${C_BOLD}Branch${C_RESET}   develop (active)"
echo -e "  ${C_BOLD}Docs${C_RESET}     ./docs/"
echo ""
echo -e "${C_BOLD}Required secrets (set once):${C_RESET}"
echo -e "  ${C_DIM}gh secret set AWS_STAGING_ROLE_ARN"
echo -e "  gh secret set AWS_PRODUCTION_ROLE_ARN"
echo -e "  gh secret set AWS_REGION"
echo -e "  gh secret set ECR_REGISTRY"
echo -e "  gh secret set SLACK_WEBHOOK_URL${C_RESET}"
echo ""
echo -e "${C_BOLD}Start working:${C_RESET}"
echo -e "  ${C_BLUE}git checkout -b feature/your-feature develop${C_RESET}"
echo ""
echo -e "${C_DIM}Production deploy gate active — every push to main"
echo -e "requires your explicit approval in GitHub → Actions → Environments.${C_RESET}"
echo ""
