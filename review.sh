#!/usr/bin/env bash
# ============================================================
# review.sh — Review deliverables of a factory-generated project
#
# Usage: ./review.sh [project-dir]
#        ./review.sh                  (picks the latest project)
# ============================================================
set -euo pipefail

FACTORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="$FACTORY_DIR/projects"

C_RESET='\033[0m'; C_BOLD='\033[1m'
C_GREEN='\033[92m'; C_YELLOW='\033[93m'; C_RED='\033[91m'

ok()   { echo -e "${C_GREEN}✓${C_RESET}  $*"; }
warn() { echo -e "${C_YELLOW}!${C_RESET}  $*"; }
err()  { echo -e "${C_RED}✗${C_RESET}  $*" >&2; exit 1; }

# ── Resolve project dir ──────────────────────────────────────
if [[ $# -gt 0 ]]; then
  PROJECT_DIR="$1"
else
  LATEST=$(find "$PROJECTS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
  [[ -n "$LATEST" ]] || err "No projects found in $PROJECTS_DIR"
  PROJECT_DIR="$PROJECTS_DIR/$LATEST"
fi

[[ -d "$PROJECT_DIR" ]] || err "Not a directory: $PROJECT_DIR"

echo ""
echo -e "${C_BOLD}━━━ Reviewing: $(basename "$PROJECT_DIR") ━━━━━━━━━━━━━━━━━${C_RESET}"
echo ""

# ── Check plan ────────────────────────────────────────────────
if [[ -f "$PROJECT_DIR/plan.json" ]]; then
  ok "plan.json present"
  PROJECT_NAME=$(python3 -c "import json; print(json.load(open('$PROJECT_DIR/plan.json')).get('projectName','?'))" 2>/dev/null || echo "?")
  echo -e "   Project: ${C_BOLD}$PROJECT_NAME${C_RESET}"
else
  warn "plan.json missing"
fi

# ── Check deliverables ───────────────────────────────────────
echo ""
TEAMS=("backend" "frontend" "platform" "qa" "security" "docs")
TOTAL=0
FOUND=0

for team in "${TEAMS[@]}"; do
  TOTAL=$((TOTAL + 1))
  DELIVERABLE="$PROJECT_DIR/$team/deliverable.md"
  if [[ -f "$DELIVERABLE" ]]; then
    LINES=$(wc -l < "$DELIVERABLE" | tr -d ' ')
    FOUND=$((FOUND + 1))
    ok "$team: $LINES lines"
  else
    warn "$team: missing"
  fi
done

echo ""
echo -e "${C_BOLD}Deliverables: $FOUND / $TOTAL${C_RESET}"

if [[ $FOUND -eq $TOTAL ]]; then
  echo -e "${C_GREEN}All deliverables present.${C_RESET}"
else
  echo -e "${C_YELLOW}Some deliverables are missing — re-run factory.sh if needed.${C_RESET}"
fi

echo ""
