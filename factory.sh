#!/usr/bin/env bash
# ============================================================
# Boring SW Factory — Multi-Agent Orchestrator
# Usage: ./factory.sh "your project brief here"
#        ./factory.sh --file brief.md
# ============================================================
set -euo pipefail

FACTORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$FACTORY_DIR/agents"
PROJECTS_DIR="$FACTORY_DIR/projects"

# ── Colors ───────────────────────────────────────────────────
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_PM='\033[35m'        # purple
C_BACKEND='\033[34m'   # blue
C_FRONTEND='\033[32m'  # green
C_PLATFORM='\033[33m'  # yellow
C_QA='\033[31m'        # red
C_SUCCESS='\033[92m'
C_DIM='\033[2m'

log()     { echo -e "${C_DIM}[$(date +%H:%M:%S)]${C_RESET} $*"; }
log_pm()  { echo -e "${C_PM}${C_BOLD}[PM]${C_RESET}       $*"; }
log_ok()  { echo -e "${C_SUCCESS}${C_BOLD}[✓]${C_RESET}       $*"; }

# ── Parse args ───────────────────────────────────────────────
BRIEF=""
if [[ $# -eq 0 ]]; then
  echo -e "${C_BOLD}Boring SW Factory${C_RESET} — Multi-Agent Orchestrator"
  echo ""
  echo "Usage:"
  echo "  ./factory.sh \"Build a real-time chat app with auth and notifications\""
  echo "  ./factory.sh --file brief.md"
  echo ""
  exit 0
elif [[ "$1" == "--file" ]]; then
  BRIEF=$(cat "$2")
else
  BRIEF="$*"
fi

# ── Phase 0: Setup ───────────────────────────────────────────
echo ""
echo -e "${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_BOLD}  BORING SW FACTORY — Initializing${C_RESET}"
echo -e "${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo ""

# ── Phase 1: PM Analysis ─────────────────────────────────────
log_pm "Analyzing project brief…"

PM_SYSTEM=$(cat "$FACTORY_DIR/CLAUDE.md")
PM_PROMPT="PROJECT BRIEF:\n${BRIEF}"

PM_OUTPUT=$(echo -e "$PM_PROMPT" | claude --print \
  --system-prompt "$PM_SYSTEM" 2>/dev/null)

# Extract JSON (handle potential preamble)
PLAN_JSON=$(echo "$PM_OUTPUT" | python3 -c "
import sys, json, re
raw = sys.stdin.read()
# Try to extract JSON object
match = re.search(r'\{[\s\S]*\}', raw)
if match:
    try:
        obj = json.loads(match.group())
        print(json.dumps(obj))
    except:
        print(raw)
else:
    print(raw)
" 2>/dev/null || echo "$PM_OUTPUT")

# Parse plan fields
PROJECT_NAME=$(echo "$PLAN_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('projectName','project'))" 2>/dev/null || echo "project")
PROJECT_SLUG=$(echo "$PLAN_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('slug','project'))" 2>/dev/null || echo "project")
COMPLEXITY=$(echo "$PLAN_JSON"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('complexity','medium'))" 2>/dev/null || echo "medium")
TECH_STACK=$(echo "$PLAN_JSON"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('techStack','TBD'))" 2>/dev/null || echo "TBD")
TEAMS=$(echo "$PLAN_JSON"        | python3 -c "import sys,json; d=json.load(sys.stdin); print(' '.join(d.get('teams',['backend','frontend','platform','qa'])))" 2>/dev/null || echo "backend frontend platform qa")

log_pm "Project: ${C_BOLD}$PROJECT_NAME${C_RESET} (${COMPLEXITY})"
log_pm "Stack:   $TECH_STACK"
log_pm "Teams:   $TEAMS"
echo ""

# ── Setup project dir ────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="$PROJECTS_DIR/${TIMESTAMP}_${PROJECT_SLUG}"
mkdir -p "$PROJECT_DIR"/{backend,frontend,platform,qa}

# Save plan
echo "$PLAN_JSON" > "$PROJECT_DIR/plan.json"
echo "$BRIEF"     > "$PROJECT_DIR/brief.md"

log "Project directory: $PROJECT_DIR"
echo ""

# ── Phase 2: Parallel team execution ─────────────────────────
echo -e "${C_BOLD}━━━ Teams Starting (parallel) ━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo ""

run_team() {
  local TEAM_ID="$1"
  local COLOR="$2"
  local LABEL="$3"

  # Get team-specific work from plan
  local TEAM_WORK
  TEAM_WORK=$(echo "$PLAN_JSON" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d.get('${TEAM_ID}Work', 'Handle all ${TEAM_ID} aspects of the project'))
" 2>/dev/null || echo "Handle all ${TEAM_ID} aspects")

  local SYSTEM_PROMPT
  SYSTEM_PROMPT=$(cat "$AGENTS_DIR/${TEAM_ID}.md")

  local USER_PROMPT
  USER_PROMPT="PROJECT: $PROJECT_NAME
SUMMARY: $(echo "$PLAN_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('summary',''))" 2>/dev/null)
TECH STACK: $TECH_STACK
YOUR ASSIGNMENT: $TEAM_WORK
MVP DELIVERABLE: $(echo "$PLAN_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('mvpDeliverable',''))" 2>/dev/null)"

  echo -e "${COLOR}${C_BOLD}[${LABEL}]${C_RESET}${COLOR} Starting…${C_RESET}"

  echo -e "$USER_PROMPT" | claude --print \
    --system-prompt "$SYSTEM_PROMPT" \
    > "$PROJECT_DIR/${TEAM_ID}/deliverable.md" 2>/dev/null

  echo -e "${C_SUCCESS}${C_BOLD}[✓ ${LABEL}]${C_RESET} Deliverable written → ${TEAM_ID}/deliverable.md"
}

# Launch teams in parallel based on PM plan
PIDS=()
for TEAM in $TEAMS; do
  case "$TEAM" in
    backend)  run_team "backend"  "$C_BACKEND"  "Backend"   & PIDS+=($!) ;;
    frontend) run_team "frontend" "$C_FRONTEND" "Frontend"  & PIDS+=($!) ;;
    platform) run_team "platform" "$C_PLATFORM" "Platform"  & PIDS+=($!) ;;
    qa)       run_team "qa"       "$C_QA"       "QA"        & PIDS+=($!) ;;
    security) run_team "security" "$C_QA"       "Security"  & PIDS+=($!) ;;
    docs)     run_team "docs"     "$C_PM"       "Docs"      & PIDS+=($!) ;;
  esac
done

# Wait for all teams
for PID in "${PIDS[@]}"; do
  wait "$PID"
done

# ── Phase 3: Summary ─────────────────────────────────────────
echo ""
echo -e "${C_BOLD}━━━ Factory Complete ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo ""

# Generate index
cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

**Generated:** $(date '+%Y-%m-%d %H:%M')
**Complexity:** $COMPLEXITY
**Stack:** $TECH_STACK

## Brief
$BRIEF

## Plan
\`\`\`json
$(cat "$PROJECT_DIR/plan.json")
\`\`\`

## Deliverables
EOF

for TEAM in $TEAMS; do
  if [[ -f "$PROJECT_DIR/$TEAM/deliverable.md" ]]; then
    SIZE=$(wc -l < "$PROJECT_DIR/$TEAM/deliverable.md")
    echo "- **${TEAM}/** — ${SIZE} lines" >> "$PROJECT_DIR/README.md"
    log_ok "$TEAM: $(wc -l < "$PROJECT_DIR/$TEAM/deliverable.md") lines"
  fi
done

echo ""
echo -e "${C_BOLD}📁 Project:${C_RESET} $PROJECT_DIR"
echo ""
echo -e "${C_DIM}Pending your validation as Product Owner.${C_RESET}"
echo ""
