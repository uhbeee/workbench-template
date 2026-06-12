# Workbench

## Session Bootstrap

**Before doing anything else**, read `config.yaml` in the repository root. This file contains all personal configuration: user identity, GitHub org, Jira projects, Confluence spaces, Slack channels, team structure, capacity defaults, and estimation multipliers. Every agent and process in this workspace references config values loaded from this file.

If `config.yaml` does not exist, tell the user to copy `config.example.yaml` to `config.yaml` and fill in their values.

## Repository Setup

This is a **private** workbench instance. Two repos are in play:

- **Private** (`origin`): Everything committed — context files, archives, plans. This is your working repo.
- **Public template** (`template` remote): Shareable template with safe content only.

All context files are version-controlled here. Commit them normally.

Template sync uses an **inverted allowlist** (`scripts/template-allowlist.yaml`): skills and files are excluded from the template by default. Each must be explicitly listed to sync. New skills never accidentally leak to the public template.

To sync safe content to the template, run `/template-sync`.

## AI Tooling Structure

This workspace uses the `.agents/` directory as the **single source of truth** for all AI tooling:

- **`.agents/agents/`** — Agent definitions (.md files). Each is a standalone agent invoked via Claude Code or Cursor.
- **`.agents/skills/`** — All skills (~45). Each skill has a `SKILL.md` defining its behavior.
- **`.agents/hooks/`** — Shared hook scripts (.py files) for session lifecycle events.
- **`.agents/mcp.json`** — MCP server configuration shared across tools.

Tool-specific directories (`.claude/`, `.cursor/`) contain junctions pointing back to `.agents/`:
- `.claude/agents` -> `.agents/agents` (junction)
- `.claude/skills` -> `.agents/skills` (junction)
- `.claude/hooks` -> `.agents/hooks` (junction)
- `.claude/CLAUDE.md` -> `AGENTS.md` (symlink)
- `.cursor/agents`, `.cursor/skills`, `.cursor/hooks` -> same pattern

Junctions are created by `scripts/setup.sh` and are gitignored. They are NOT committed.
Tool-specific files (`.claude/settings.json`, `.claude/settings.local.json`, `.cursor/rules/`) remain in their respective directories.

## Claude Code Settings

The `.claude/` directory contains Claude Code configuration for this workspace:

- **`.claude/CLAUDE.md`** — Symlink to `AGENTS.md` (this file). Read automatically at session start. Defines session behavior, accountability loops, and all workflow instructions.
- **`.claude/agents/`** — Junction to `.agents/agents/`. Agent definitions invoked via Claude Code (e.g., `morning-triage`, `weekly-plan`, `template-sync`).
- **`.claude/skills/`** — Junction to `.agents/skills/`. Skill definitions with `SKILL.md` files.
- **`.claude/hooks/`** — Junction to `.agents/hooks/`. Hook scripts for session lifecycle events.
- **`.claude/settings.local.json`** — MCP tool permissions. Pre-approves Atlassian, Slack, Figma, git, and web search so agents can run without repeated permission prompts.

## Worktree Isolation — never plan or generate code on develop/main

Any Workbench skill that creates a plan, generates or edits code, or otherwise touches files in a managed repo MUST do that work in an isolated feature worktree — **never directly on `develop`/`main`** (or `master`/`staging`/`production`/`release/*`). You can run everything *from* `develop`; the worktree is created, worked in, and removed for you.

- **Guard at the start of the work.** If the current checkout is on a protected branch, create a feature worktree first (via the `worktree-feature-create` skill) and do every edit there.
- **Fallback when the tooling/skill is absent.** If `worktree-feature-create` or the canonical Workbench worktree tooling isn't available (e.g. a machine without Workbench), still create the worktree with plain `git worktree add -b <branch> <path> <base>` (see worktree-feature-create's "Non-Workbench Fallback"). Do NOT fall through to editing on the protected branch.
- **Cleanup policy.** After the work lands, remove the worktree + local branch (the `ship` skill does this on merge; `worktree-remove` otherwise). **Delete after merge/success; keep the worktree on failure** so it can be debugged.
- **Exemptions.** Read-only / advisory skills (triage, status, research notes, calendar, etc.) are exempt — this rule targets plan-generating and code-touching work.
- **Scope.** This is a Workbench-skill rule. Repo-local skills (e.g. spot-v2's own) follow their own repo's conventions.

## What This Is

This is the operational hub for a senior/principal software engineer. It is NOT a code repository. It is where you come to think, plan, gather context, and stay accountable.

Every session in this workspace should start by checking for today's daily plan.

## Role Context

The user's identity and organizational context are defined in `config.yaml`:
- **Name, role, organization**: `config.yaml: user.*`
- **Slack display name**: `config.yaml: user.slack_display_name` — use this when searching for DMs and @mentions
- **GitHub org and repositories**: `config.yaml: github.*`
- **Jira project keys**: `config.yaml: jira.projects[]` — each entry has a key, name, description, and ticket pattern
- **Confluence spaces**: `config.yaml: confluence.spaces[]` — each entry has a key, name, and description

## Accountability Loop

**At the start of EVERY session**, do the following before anything else:

1. Check if a daily plan exists at `context/active/daily.md`
2. Check if a weekly plan exists at `context/active/weekly.md`
3. If both exist: briefly summarize daily progress (items done/total), weekly capacity (hours committed/available), and the top priority. Ask if priorities have shifted.
4. If the daily plan is missing, suggest running the morning-triage agent.
5. If the weekly plan is missing, suggest running the weekly-plan agent.

This is non-negotiable. The daily plan keeps you focused. The weekly plan keeps you honest about capacity.

## Capacity Model

Defaults are defined in `config.yaml: capacity`. Use those values unless the user provides different numbers:

- **Daily productive hours**: `capacity.daily_productive_hours` (not 8 — meetings, Slack, context switching)
- **Weekly productive hours**: `capacity.weekly_productive_hours`
- **Meeting overhead**: `capacity.meeting_overhead` per week (adjust based on actual calendar)
- **Slack/comms overhead**: `capacity.slack_overhead` per week
- **Context switching**: `capacity.context_switching` per week
- **Interrupt buffer**: `capacity.interrupt_buffer` per week (non-negotiable — interrupts are guaranteed)

When assessing whether something fits in the schedule, always use the realistic capacity, never the theoretical 40h.

## Estimation Philosophy

**The user chronically underestimates task duration.** Every estimate must account for this:

1. Break tasks into subtasks including "hidden work" (PR review cycles, merge conflicts, Slack alignment, deploy verification)
2. Apply multipliers from `config.yaml: estimation.multipliers` based on familiarity:
   - Familiar code + clear requirements: `estimation.multipliers.familiar_clear`
   - Familiar code + unclear requirements: `estimation.multipliers.familiar_unclear`
   - Unfamiliar code + clear requirements: `estimation.multipliers.unfamiliar_clear`
   - Unfamiliar code + unclear requirements: `estimation.multipliers.unfamiliar_unclear`
   - System never touched: `estimation.multipliers.never_touched`
3. Never give best-case as the timeline. Always communicate the realistic estimate.
4. Track actuals vs estimates in the weekly plan to calibrate over time.

When the user says "it should only take X hours" — that's the bias. Ask them to walk through the subtasks. The breakdown always reveals more work.

## Weekly Plan File Format

The current weekly plan is at `context/active/weekly.md`. Previous weeks are archived to `context/archive/YYYY/MM/weekly/YYYY-WNN.md`. See the weekly-plan agent for the full format. Key sections:
- Capacity calculation
- Committed work with estimates and actuals
- Stretch goals (not commitments)
- Estimation accuracy tracker
- Interrupts log

## Slack Channel Map

Channel names and descriptions are defined in `config.yaml: slack.channels`, organized by category:

- **Product** (`slack.channels.product`): Product health and customer-facing issues
- **Engineering** (`slack.channels.engineering`): What the team is building
- **Operations** (`slack.channels.operations`): Infrastructure, incidents, deployments
- **General** (`slack.channels.general`): Company-wide and system alerts

Agents use these categories for priority ordering. Operations channels are checked first (incidents have highest urgency), then product, then engineering, then general.

## Jira Context

Jira projects are defined in `config.yaml: jira.projects[]`. Each project has:
- A `key` used in JQL queries (e.g., `project = <key>`)
- A `ticket_pattern` showing the ID format
- A `name` and `description` for context

When reviewing tickets, always check for linked Confluence docs, linked tickets, and recent comments.

## Confluence Context

Confluence spaces are defined in `config.yaml: confluence.spaces[]`. Each space has:
- A `name` used in CQL queries (e.g., `space = "<name>"`)
- A `description` of what lives there

## Quarterly Goals

The user's team structure is defined in `config.yaml: teams[]`. Each team maps to a Jira project and Confluence space for goal tracking.

Goals file: `context/active/goals.md` (archived to `context/archive/YYYY/QN/goals.md` on quarter rollover)

**Mid-quarter goal additions are normal.** When new goals appear:
1. Run the quarterly-goals agent to assess capacity impact
2. Log the change in the scope change log
3. Communicate what gets displaced

Weekly plans should always reference quarterly goals. If a weekly plan has no hours mapped to an at-risk goal, flag it.

## Calendar Integration

Meeting data comes from the user's calendar via browser automation.
- Calendar provider and URL are defined in `config.yaml: calendar`
- Calendar file: `context/active/calendar.md` (archived to `context/archive/YYYY/MM/calendar/YYYY-WNN.md`)
- Run the `calendar-sync` agent to refresh from the calendar
- Morning triage and weekly planning use this for real capacity numbers instead of guesses
- If the calendar file is stale (older than the current week), suggest re-syncing

## Estimation Calibration

The system learns over time. Estimation accuracy data lives in `context/calibration.md`.
- Tracks actual vs estimated hours per task
- Adjusts multipliers as data accumulates (low/medium/high confidence thresholds)
- Tracks a weekly pace factor to account for energy, focus, and mental load variations
- The estimate agent reads this file before every estimation

**Pace factor**: Some weeks are slower and that's fine. The system doesn't judge — it adjusts. A pace factor of 0.8 means "this week, things are taking 25% longer than normal" and estimates are adjusted accordingly.

## Tool Usage

This workspace leverages MCP integrations:
- **Atlassian**: For Jira and Confluence (read tickets, search, read docs)
- **Slack**: For channel reading, thread reading, and sending messages
- **Figma**: For design context when reviewing UI-related work
- **Chrome**: For reading the calendar and other browser-based tasks

When using these tools, always prefer structured summaries over raw dumps. Extract what matters, flag what needs attention, and skip the noise.

## Active vs Archive File Structure

Current plans live in `context/active/` with fixed filenames:
- `context/active/daily.md` — today's plan
- `context/active/weekly.md` — this week's plan
- `context/active/calendar.md` — this week's calendar
- `context/active/goals.md` — current quarter's goals

Historical files are archived under `context/archive/` organized by year/month:
- `context/archive/YYYY/MM/daily/YYYY-MM-DD.md` — archived daily plans
- `context/archive/YYYY/MM/weekly/YYYY-WNN.md` — archived weekly plans
- `context/archive/YYYY/MM/calendar/YYYY-WNN.md` — archived calendar data
- `context/archive/YYYY/QN/goals.md` — archived quarterly goals (quarter-scoped)

**Archive process** (built into existing agents, no separate agent needed):
- **Morning triage**: Before creating today's plan, checks if `context/active/daily.md` is from a previous day. If so, moves it to `context/archive/YYYY/MM/daily/YYYY-MM-DD.md`, then creates a fresh `context/active/daily.md`.
- **Weekly plan**: Before creating this week's plan, archives `context/active/weekly.md` to `context/archive/YYYY/MM/weekly/YYYY-WNN.md` and `context/active/calendar.md` to `context/archive/YYYY/MM/calendar/YYYY-WNN.md`.
- **Quarterly goals**: On quarter rollover, archives `context/active/goals.md` to `context/archive/YYYY/QN/goals.md`.

Cross-quarter data (`context/calibration.md`, `context/notes/`) stays in place — not archived.

## Daily Plan File Format

The current daily plan is at `context/active/daily.md` with this structure:

```markdown
# Daily Plan - YYYY-MM-DD

## Capacity Today
- Available hours: Xh (after meetings)
- Committed: Xh
- Remaining: Xh

## DMs and @Mentions
- [ ] @person — summary of what they need (DM / #channel mention) [est: Xh]

## Top Priorities
1. [ ] Priority item (WHY: reason, WHO is waiting) [est: Xh]
2. [ ] Priority item (WHY: reason, DEADLINE: date) [est: Xh]

## Carried Forward
- [ ] Item from yesterday (originally planned YYYY-MM-DD) [est: Xh]

## Slack Threads Needing Response
- #channel - thread summary (from @person)

## Meetings Today
- HH:MM - Meeting name (context: relevant ticket/doc)

## Interrupts
(Added as they happen — track what was not planned)
- [time] Interrupt from [who]: [what] [est: Xh, actual: Xh]

## Notes
(Added throughout the day)

## End of Day
- Completed: X/Y items
- Planned hours: Xh | Actual hours: Yh
- Unanswered DMs: any
- Interrupts absorbed: Xh
- Rolled forward: list
- Blockers: any
```

## Worktree Management

Git worktree scripts live in `scripts/windows/` and `scripts/mac/`. The repo registry and worktree root are configured in `config.yaml: worktrees`.

Shell functions (`wt-feature`, `wt-review`, `wt-status`, etc.) are loaded via `scripts/windows/wt-profile.sh` (sourced in `~/.bashrc`) or `scripts/mac/wt-profile.zsh` (sourced in `~/.zshrc`).

All repo-changing work should happen in managed worktrees. Do not implement, hotfix, release-edit, or review from `main`, `develop`, `master`, or a bare repo root unless the user explicitly overrides this rule for a one-off command.

Key commands:
- `wt-status` — Show all worktrees across managed repos
- `wt-feature <branch>` — Create a feature worktree
- `wt-review <PR#>` — Create a review worktree for a PR
- `wt-release <version>` — Create a release branch
- `wt-hotfix <name>` — Create a hotfix worktree

Windows `.cmd` wrappers in `scripts/windows/bin/` allow running from any terminal (added to PATH by setup).

Agent routing rules:
- For implementation requests such as "create a worktree for <repo> and do the following", use the `worktree-feature-create` skill first, enter the printed `WORKTREE_PATH`, and implement there.
- If work was accidentally done in `develop`, `main`, or another base checkout, use `worktree-feature-create` to create a proper feature worktree, migrate the dirty diff into it, verify the diff, and only clean the base checkout after explicit approval.
- For cleanup requests such as "remove all worktrees merged to develop", use `worktree-remove` with a dry-run merged inventory first. Remove only clean managed worktrees whose branch is already merged; skip dirty/protected worktrees and report them.
- For PR review requests such as "let's review this PR", use `worktree-review-create`; create the review checkout and produce a `reviewer-packet.html` using the HTML review packet standard.
- For release requests, use `cut-release`; release branches should get a managed `_release/` worktree for follow-up work instead of editing `develop` or `main`.
- For hotfixes, use `hotfix` for both plain hotfix branches and cherry-picking an already merged PR to a release branch. PPE/prod hotfixes should use separate target-specific worktrees and keep `develop` and `main` clean.

## Global Skills

Skills that should be available in every Claude Code and Codex project are listed in `skills-global.yaml` (falling back to `config.yaml: skills.global` for legacy configs). The setup script (`scripts/setup-global-skills.sh`) creates junctions from `~/.claude/skills/<name>` and `~/.codex/skills/<name>` to `.agents/skills/<name>` (the physical path in this repo).

This means a skill authored once in `.agents/skills/my-skill/SKILL.md` becomes available in every project without duplication.

## Implementation & Shipping Workflow

The full engineering workflow from plan to PR:
1. `/forge <name>` — Plan the feature (produces plan.html + handoff.md + progress.md)
2. `/implement <name>` — Execute the plan step-by-step (TDD, progress tracking, boundary checkpoints)
3. `/ship` — Review code, create PR, link Jira, mark plan done

## HTML Planning Standard

Saved, shared, or reviewable human-readable artifacts should be HTML-first. This includes feature plans, implementation plans, PRDs, research reports, sounding-board analyses, ticket breakdowns, validation plans, context packets, reviewer packets, PR breakdowns, status reports, demo packages, and strategic planning artifacts. Before creating or updating one of these artifacts, read `context/standards/html-plan-standard.md` and follow it.

The previous `write-html` skill is intentionally inactive and kept only for experimentation at `.agents/inactive-skills/write-html/`. Do not rely on it as an active Workbench skill unless it is restored to `.agents/skills/write-html/`.

- Use `plan.html`, `prd.html`, `research.html`, `analysis.html`, `validation-plan.html`, `context-packet.html`, `reviewer-packet.html`, `pr-breakdown.html`, or another purpose-named `.html` file as the primary human-readable artifact.
- Keep Markdown only for compatibility with existing automations, prompts, and paste targets (`state.md`, `progress.md`, `activity.md`, `handoff.md`, `daily.md`, `weekly.md`, `goals.md`, `jira-draft.md`, `pr-draft.md`, and short `.md` summaries that link to HTML).
- If both HTML and Markdown exist, the HTML file is the source of truth for human review; the Markdown file is an index, prompt, tracker, or compatibility shim.
- PR breakdowns should follow the implementation-plan pattern: milestone timeline, data/service flow, risky code or contract snippets, risk table, open questions, validation, and reviewer focus.
- The HTML must be self-contained, directly openable in a browser, responsive, and readable by an engineer who does not have the chat history.
- Validate HTML artifacts with `.agents/inactive-skills/write-html/scripts/validate_html.py` when available.

For code review of others' PRs:
1. Use `pr-context` agent to gather Jira ticket + design doc + Slack discussion
2. Switch to the worktree environment: `wt-review <PR#>` in the relevant repo
3. After review, come back here to update daily plan / respond on Slack if needed

## Context Management

Manage context window usage deliberately:

- **Compact at logical breakpoints**, not at 95% capacity. Good moments: after completing a research phase, after a milestone, after abandoning a failed approach. The pre-compact hook preserves forge state and daily plan context automatically.
- **If context usage exceeds ~70%**, prefer completing the current phase before starting new work. Finish what you're doing, save state, then compact or start a new session.
- **For long multi-phase work** (like `/forge`), save state to disk between phases. The continuation.md file ensures clean handoff after compaction.
- **Kill switch**: Set `WB_HOOKS_DISABLED=1` to disable all non-safety hooks when doing quick fixes where hook overhead isn't wanted.

## Writing Style

Be direct. No fluff. Bullet points over paragraphs. When summarizing docs or tickets, lead with the decision or action needed, then provide supporting context.
