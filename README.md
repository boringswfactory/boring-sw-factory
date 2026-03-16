# Boring SW Factory

Template repository to bootstrap software projects with Claude Code agents.
Gitflow, security and documentation built-in by default. No extra API keys required.

## Start a new project

```bash
# 1. Create a repo from this template
gh repo create my-org/my-project \
  --template my-org/boring-sw-factory \
  --private --clone

# 2. Enter the project and bootstrap
cd my-project
./bootstrap.sh
```

`bootstrap.sh` handles everything else automatically:
initializes Gitflow, applies GitHub templates, configures branch protection,
sets up the production approval gate with your user,
launches 6 agents in parallel and commits the deliverables to `develop`.

## Factory structure

```
boring-sw-factory/
├── .github/workflows/validate.yml   ← Factory CI (validates agents + scripts)
├── agents/
│   ├── backend.md                   ← Backend Lead
│   ├── frontend.md                  ← Frontend Lead
│   ├── platform.md                  ← Platform Lead (infra + Gitflow + CI/CD)
│   ├── qa.md                        ← QA Lead
│   ├── security.md                  ← Security Lead (threat model, OWASP, gates)
│   └── docs.md                      ← Docs Lead (ADRs, Mermaid, user docs)
├── project-templates/               ← Applied to each new project
│   ├── .github/
│   │   ├── CODEOWNERS               ← You as reviewer on everything
│   │   ├── pull_request_template.md
│   │   └── workflows/
│   │       ├── ci.yml               ← lint, test, SAST, secrets, trivy, build
│   │       ├── cd-staging.yml       ← Auto-deploy to staging
│   │       └── cd-production.yml    ← Manual approval gate (you)
│   └── docs/architecture/decisions/ADR-000-template.md
├── scripts/
│   ├── bootstrap.sh     ← Entry point for new projects
│   ├── setup-github.sh  ← Branch protection + environments via gh cli
│   └── publish.sh       ← Publish/update this repo as a template on GitHub
├── CLAUDE.md            ← PM system prompt (work breakdown schema)
├── factory.sh           ← Multi-agent orchestrator
└── review.sh            ← Review deliverables of a project
```

What gets into each new project (not factory code):

```
my-project/
├── .github/             ← From project-templates/
├── docs/
│   ├── brief.md
│   ├── plan.json        ← Work breakdown from PM
│   ├── backend/deliverable.md
│   ├── frontend/deliverable.md
│   ├── platform/deliverable.md
│   ├── qa/deliverable.md
│   ├── security/deliverable.md
│   └── docs/deliverable.md
└── README.md
```

The factory scripts (`factory.sh`, `bootstrap.sh`, `agents/`...)
are self-removed from the project after bootstrap — they live versioned here.

## Standards applied to all projects

| Area | Standard |
|------|----------|
| Branching | Gitflow: `main`, `develop`, `feature/*`, `release/*`, `hotfix/*` |
| Merge to `main` | PR + your review (CODEOWNERS) + full CI green |
| Production deploy | Manual approval by you in GitHub Environments |
| CI | Lint → Test → SAST (Semgrep) → Secrets (TruffleHog) → Deps (Trivy) → Build |
| CD staging | Auto on push to `develop` and `release/*` |
| CD production | Promote same image from staging (no rebuild) |
| Security | Threat model, OWASP mapping, supply chain, security gates per project |
| Documentation | ADRs, Mermaid C4 diagrams, API spec, runbooks, user docs |

## Publish / update the factory

```bash
# First time — creates the repo and marks it as template
./scripts/publish.sh my-org

# Update (changes to agents, templates, workflows)
git add . && git commit -m "feat(agents): improve security prompt"
git push origin main
# → Factory CI validates changes automatically
```

## Evolving the factory

### Improve an agent

```bash
git checkout -b feature/improve-security-agent
# edit agents/security.md
git push origin feature/improve-security-agent
gh pr create --base main
# → CI validates → PR review → merge → all future projects benefit
```

### Add a new team (e.g. Data/ML)

```bash
# 1. Create the system prompt
cat > agents/data.md << 'EOF'
# Data / ML Lead
...
EOF

# 2. Add to the orchestrator in factory.sh
# data) run_team "data" "$C_BLUE" "Data/ML" & PIDS+=($!) ;;

# 3. Add to the schema in CLAUDE.md
# "data": "scope of data/ML work"
```

### Update a CI/CD template for all future projects

```bash
# Edit project-templates/.github/workflows/ci.yml
# The change applies to all projects created from this point onward
# Existing projects must update manually (or with a migration script)
```

## Personal config

`~/.config/boring-sw-factory/env` (created automatically on first bootstrap):
```bash
FACTORY_OWNER="your-github-username"
FACTORY_ORG="your-org"
```
