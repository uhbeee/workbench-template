# Workbench

Operational hub for a principal software engineer, powered by Claude Code. Plan, prioritize, estimate, review code, and stay accountable — all from one repo.

This is **not** a code repository. It's where you think, plan, gather context, and manage your engineering workflow. Skills authored here are distributed globally via symlink — available in every project.

## What's Inside

- **Agents** (`.agents/agents/`) — 20 AI agent definitions for daily workflows: morning triage, weekly planning, estimation, Jira/Confluence/Slack integration, PR review, and more.
- **Skills** (`.agents/skills/`) — 45 invocable skills covering operational planning, code review, security scanning, QA, implementation, shipping, and meta-workflows.
- **Hooks** (`.agents/hooks/`) — Session lifecycle hooks that inject daily context, log Slack messages, check plan status, and suggest code review before commits.
- **Scripts** (`scripts/`) — Cross-platform shell scripts for setup, diagnostics, skill validation, worktree management, and template sync.
- **Context** (`context/`) — Daily plans, weekly plans, calendar data, quarterly goals, feature plans, and archived history.

## Quick Start

### Prerequisites

- Git (with Git Bash on Windows)
- Python 3.x
- [Claude Code](https://claude.ai/claude-code) CLI
- GitHub CLI (`gh`) — optional but recommended

### Setup

```bash
# Clone the repo
git clone https://github.com/Joshua-Palamuttam/workbench.git
cd workbench

# Run one-command setup
bash scripts/setup.sh
```

On Windows, you can also run:
```cmd
scripts\windows\bin\setup.cmd
```

Setup will:
1. Detect your platform (Windows/macOS/Linux)
2. Create `config.yaml` from the template if needed
3. Create directory junctions from `.claude/` and `.cursor/` to `.agents/`
4. Create a file symlink: `.claude/CLAUDE.md` -> `AGENTS.md`
5. Configure your shell profile for worktree commands
6. Set up global skills in `~/.claude/skills/` and `~/.codex/skills/` (available in every Claude Code and Codex project)
7. Run skill validation to verify all skills are well-formed
8. Run diagnostics to verify the environment

**Windows note:** The CLAUDE.md file symlink requires admin privileges. Setup will print the exact PowerShell command to run in an admin terminal.

### Configuration

Edit `config.yaml` to customize:

```yaml
user:
  name: "Your Name"
  role: "Your Title"
  organization: "Your Org"

worktrees:
  root: "C:/worktrees"
  repos:
    - name: my-repo
      url: https://github.com/org/repo.git
      default_base: develop
      type: standard

skills:
  global:          # Available in every project
    - estimate
    - sounding-board
    - review-code
    - security-scan
```

See `config.example.yaml` for all available options.

### Verify

```bash
bash scripts/doctor.sh
bash scripts/validate-skills.sh
# or from within Claude Code:
/doctor
```

## Architecture

### `.agents/` as Single Source of Truth

All AI tooling lives in `.agents/`. Tool-specific directories (`.claude/`, `.cursor/`) contain junctions pointing back:

```
.agents/                     # Canonical
  agents/                    # Agent definitions
  skills/                    # Skill definitions
  hooks/                     # Hook scripts
  mcp.json                   # MCP server config

.claude/                     # Claude Code (junctions)
  CLAUDE.md -> ../AGENTS.md  # Symlink
  agents -> ../.agents/agents
  skills -> ../.agents/skills
  hooks -> ../.agents/hooks
  settings.json              # Claude-specific (committed)
  settings.local.json        # Machine-specific (gitignored)
```

Junctions are gitignored and created by `scripts/setup.sh`.

### Global Skill Distribution

Skills listed in `skills-global.yaml` are symlinked to `~/.claude/skills/` and `~/.codex/skills/`, making them available in every Claude Code and Codex project without duplication. Author a skill once in `.agents/skills/my-skill/SKILL.md`, run `setup-global-skills.sh`, and it works everywhere.

## Skills

### Operational Planning

| Skill | What it does |
|-------|-------------|
| `/morning-triage` | Scan DMs, Slack, Jira to create a prioritized daily plan |
| `/weekly-plan` | Build a capacity-based weekly plan with estimation tracking |
| `/daily-checkin` | Mid-day progress check against the daily plan |
| `/end-of-day` | Review today, capture unanswered DMs, set up tomorrow |
| `/standup` | Quick 3-line standup summary from daily plan files |
| `/what-next` | Recommend next highest-impact task based on capacity and priority |
| `/capacity` | Show remaining capacity today and this week |
| `/wrap-up` | Quick daily plan update — lighter than full end-of-day |

### Estimation & Accountability

| Skill | What it does |
|-------|-------------|
| `/estimate` | Realistic time estimates with calibrated multipliers and three-point ranges |
| `/ticket-breakdown` | Decompose Jira epics into estimated subtasks including hidden work |
| `/weekly-retro` | End-of-week retro comparing planned vs actual, updating calibration |
| `/quarterly-goals` | Track quarterly goals, assess capacity impact of scope changes |
| `/interrupt` | Handle urgent interrupts — size impact, show tradeoffs against current plan |
| `/log-interrupt` | Quick interrupt logging with timestamp |
| `/delegate-or-own` | Decide whether to own or delegate a task, generate handoff briefs |

### The Trifecta: `/forge` → `/implement` → `/ship`

The complete engineering workflow — plan it, build it, ship it.

```
/forge <name>      Plan the feature (brainstorm → research → challenge → refine → plan)
/implement <name>  Build it step-by-step (TDD, progress tracking, boundary checkpoints)
/ship              Ship it (review → PR → Jira → done)
```

### Feature Planning (`/forge`)

A unified planning pipeline that chains brainstorm → intake → research → challenge → refine → create → judge → handoff with user checkpoints between each phase.

| Skill | What it does |
|-------|-------------|
| `/forge` | Full planning pipeline — one command, complete feature plan |
| `/brainstorm` | Freeform ideation and structured shortlisting (8-10 approaches) |
| `/research` | Multi-source research with confidence ratings (Confluence, Jira, Slack, web) |
| `/sounding-board` | Stress-test ideas — steelmans, challenges assumptions, pre-mortems |
| `/plan-create` | Create strategic feature plan with work breakdown and handoff prompt |

**Forge features:**
- Three depth levels: quick, standard, deep
- Scope calibration checkpoint between research and challenge (expand/hold/reduce)
- Cognitive mode annotations on every phase (Divergent Explorer, Adversarial Critic, etc.)
- Anti-compaction system preserving state across context resets
- Generates `progress.md` alongside handoff for `/implement` to consume
- External LLM judging (Claude-as-judge, with Codex/Gemini CLI support)

### Implementation (`/implement`)

Executes a forge plan step-by-step with test verification, progress tracking, and boundary checkpoints.

| Skill | What it does |
|-------|-------------|
| `/implement <plan>` | Execute a forge plan step-by-step with progress tracking |

**Features:**
- Requires a forge plan (no implementation without a plan — run `/forge --depth=quick` for small tasks)
- Checklist-based `progress.md` tracks every step's status, test results, files touched, and time
- Test-existence check before each step: if no tests exist, suggests writing one first
- Boundary checkpoints: `/structural-review --quick` at logical boundaries (layer/module transitions)
- Resume protocol: picks up where you left off after compaction or session break
- Uses `AskUserQuestion` for all decisions — never guesses

### Shipping (`/ship`)

Ships implemented code with a full review and PR creation workflow.

| Skill | What it does |
|-------|-------------|
| `/ship` | Full review → address findings → create PR → link Jira → mark plan done |

**Features:**
- Pre-flight checks: tests pass, build passes, no uncommitted changes, branch up to date
- Runs `/review-code` full adaptive pass (structural + security + QA + test suggestions)
- Critical/high findings must be addressed; medium/low noted in PR description
- Creates PR via `gh pr create` with structured body (summary, changes, testing, linked artifacts)
- Links PR to Jira ticket (comment + transition) and updates forge plan state to done
- Flags: `--draft` for draft PRs, `--skip-review` when already reviewed

### Code Review & Quality

| Skill | What it does |
|-------|-------------|
| `/review-code` | **Orchestrator** — classifies diff, invokes appropriate sub-skills adaptively |
| `/structural-review` | Staff Engineer posture — architecture, patterns, DRY, edge cases |
| `/security-scan` | Security Engineer posture — OWASP Top 10, secrets detection, dependency risks |
| `/qa-check` | QA Lead posture — diff-aware test gap analysis, regression risk |
| `/test-suggest` | TDD Coach posture — framework-aware test skeletons, red-green-refactor |

**`/review-code` adaptive classification:**
- **Trivial** (< 20 lines, no logic) → quick structural only
- **Standard** (logic changes) → structural + QA
- **Security-sensitive** (auth/API/secrets) → structural + security + QA
- **New feature** (new files) → full pass including test suggestions

Flag overrides: `--quick`, `--security-only`, `--no-security`, `--qa-only`, `--no-qa`

Includes a rationalization-blocking table (from [superpowers](https://github.com/obra/superpowers)) that maps common excuses to rebuttals.

### Context Gathering

| Skill | What it does |
|-------|-------------|
| `/pr-context` | Gather Jira ticket + design doc + Slack discussion for a PR |
| `/jira-review` | Pull a Jira ticket with linked docs, comments, and PRs |
| `/confluence-review` | Read and critically summarize a Confluence document |
| `/meeting-prep` | Gather context for an upcoming meeting from Jira, Confluence, Slack |
| `/draft-reply` | Search Slack, gather context, draft a response |
| `/slack-catch-up` | Scan Slack channels, DMs, and @mentions for actionable items |

### Release & Git

| Skill | What it does |
|-------|-------------|
| `/cut-release` | Create a release branch in a managed repo |
| `/hotfix` | Cherry-pick a merged PR into a release branch |
| `/feature-worktree-create` | Create a new feature worktree in a managed repo |
| `/worktrees` | Show git worktree status across all managed repos |

### Meta & Setup

| Skill | What it does |
|-------|-------------|
| `/doctor` | Diagnose workbench environment + validate all skills |
| `/setup` | Run one-command workbench setup |
| `/add-skill` | Import skills from GitHub URL, local path, or registry |
| `/template-sync` | Sync safe content to public template repo |
| `/sync-permissions` | Promote worktree permissions to global Claude Code settings |
| `/calendar-sync` | Read Outlook calendar via Chrome for capacity planning |
| `/status-report` | Generate stakeholder-ready status update by quarterly goals |
| `/debug-appinsights` | Query Azure Application Insights for exceptions and traces |

## Hooks

| Hook | Trigger | What it does |
|------|---------|-------------|
| `session-start-check.py` | SessionStart | Check if daily/weekly plans exist and are current |
| `inject-daily-context.py` | UserPromptSubmit | Inject top 3 priorities and capacity into every message |
| `log-slack-send.py` | PostToolUse (Slack) | Log Slack messages to daily plan notes |
| `pre-compact-context.py` | PreCompact | Preserve forge state and daily plan across compaction |
| `suggest-review.py` | PreToolUse (Bash) | Suggest `/review-code` before committing 50+ line diffs |
| `check-unlisted-skills.sh` | Pre-commit | Warn about skills not in the template allowlist |

**Kill switch:** Set `WB_HOOKS_DISABLED=1` to disable all non-safety hooks for quick fixes.

## Worktree Management

Shell functions for managing git worktrees across multiple repos:

```bash
# Core commands
wt-status              # Status across all repos
wt-feature my-branch   # Create a feature worktree
wt-review 123          # Review a PR in an isolated worktree
wt-release             # Cut a release branch
wt-hotfix fix-name     # Create a hotfix worktree

# Navigation
wtn                    # Interactive worktree picker (fzf)
wtn -                  # Toggle back to last worktree (like cd -)
wtn --code             # Navigate and launch Claude Code
wtg                    # Alias for wtn

# Cleanup
wt-remove              # Interactive worktree removal
wt-remove my-branch    # Remove a specific worktree
wt-remove --stale      # Batch-remove worktrees with no commits in 14+ days
wt-remove --stale 7    # Custom staleness threshold (days)
wt-remove -y           # Skip confirmation prompts
wtrm                   # Alias for wt-remove
```

All commands support tab completion (zsh). Scripts live in `scripts/windows/` and `scripts/mac/`. Windows `.cmd` wrappers in `scripts/windows/bin/` are added to PATH by setup.

## Template Sync

Uses an **inverted allowlist** — skills and files are excluded from the public template by default. Each must be explicitly listed in `scripts/template-allowlist.yaml` to sync. A security scan checks for sensitive patterns before any push.

## Inspiration

The code review and quality skills incorporate patterns from:
- **[superpowers](https://github.com/obra/superpowers)** — Rationalization-blocking tables, enforced methodology concepts
- **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** — Continuous learning concepts, strategic compaction
- **[gstack](https://github.com/garrytan/gstack)** — Cognitive mode separation (locking Claude into specific engineering postures per skill)

## Directory Structure

```
workbench/
  .agents/              # Canonical AI tooling
    agents/             # 20 agent definitions
    skills/             # 45 skill definitions
    hooks/              # 6 hook scripts
    mcp.json            # MCP server config
  .claude/              # Claude Code (junctions + settings)
  .cursor/              # Cursor (junctions + rules)
  scripts/
    lib.sh              # Shared cross-platform functions
    setup.sh            # One-command setup
    setup-global-skills.sh  # Symlink skills to ~/.claude/skills/ and ~/.codex/skills/
    doctor.sh           # Environment diagnostics
    validate-skills.sh  # Skill validation (frontmatter, config, hooks)
    skill-add.sh        # Skill import
    template-sync.sh    # Template sync
    windows/            # Windows worktree scripts + bin/
    mac/                # macOS worktree scripts
    appinsights/        # Azure AppInsights tooling
  templates/            # Templates for new worktrees
  context/
    active/             # Current daily/weekly/calendar/goals
    archive/            # Historical data
    plans/              # Feature plans (/forge artifacts)
    notes/              # Research and drafts
    calibration.md      # Estimation accuracy tracker
  config.yaml           # Personal config (gitignored)
  config.example.yaml   # Config template
  AGENTS.md             # Canonical instructions (symlinked to .claude/CLAUDE.md)
```
