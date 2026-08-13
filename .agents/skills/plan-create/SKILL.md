---
name: plan-create
description: Create a Markdown-first strategic feature plan with work breakdown and a handoff prompt for the target repo. Interviews for ambiguities, reads research/analysis artifacts if available. Use after research and refinement, or standalone when you already have context.
metadata:
  workbench.argument-hint: "<plan-name>"
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Plan Create

Create a strategic feature plan with work breakdown and a handoff prompt ready to paste into the target repo. This skill interviews the user to resolve all ambiguities, synthesizes research and analysis artifacts, and produces a Markdown-first plan plus implementation handoff: `plan.md` (primary source-of-truth plan), `plan.html` (optional visual companion when the plan has substantial diagrams or visual hierarchy), and `handoff.md` (ready-to-paste prompt for implementation).

## Process

### Step 1: Load Context

1. **Read `config.yaml`** from the repository root for user identity, GitHub repos, Jira projects, and Confluence spaces.
2. **Determine the plan name** from the first argument (`$0`). If no argument, use `AskUserQuestion` to get it.
3. **Check for existing artifacts** at `context/plans/active/<plan-name>/`:
   - `plan.html` — primary HTML plan artifact
   - `plan.md` — compatibility synopsis or older Markdown plan
   - `research.html` — primary evidence base from the researcher
   - `analysis.html` — primary critical analysis from the sounding board
   - `research.md` / `analysis.md` — compatibility synopses or legacy artifacts
   - `state.md` — current phase tracking
4. If neither `research.html` nor `analysis.html` exists, that's fine — the user may have context from other sources or wants to plan from scratch. Note this and proceed.
5. **Run repo-context preflight** by invoking the `repo-context` skill when the user, artifacts, or current directory imply a target repo/service. Use its bundled helper for deterministic output:
   - `python3 <workbench-root>/.agents/skills/repo-context/scripts/repo_context.py explain --repo <repo> --include-adjacent`
   - or `python3 <workbench-root>/.agents/skills/repo-context/scripts/repo_context.py explain --service <service> --include-adjacent`
   - Use `--current` when invoked from the target repo worktree.
   - Save a scoped packet when the plan will be saved: `python3 <workbench-root>/.agents/skills/repo-context/scripts/repo_context.py snapshot --repo <repo> --include-adjacent --output context/plans/active/<plan-name>/repo-context.html`.
   - Read repo-specific rule entrypoints returned by repo-context (`repo_rule_entrypoints`, `instruction_dirs`, `context_files`, service `inspect_first`) before finalizing target repo assumptions.

### Step 2: Initialize Plan Directory

If `context/plans/active/<plan-name>/` doesn't exist, create it with a `state.md`:

```markdown
# Feature Plan State: <plan-name>
## Status
- Current phase: plan
- Created: YYYY-MM-DD
- Last updated: YYYY-MM-DD
## Phase History
| Phase | Status | Started | Completed | Notes |
|-------|--------|---------|-----------|-------|
| plan | in-progress | YYYY-MM-DD | — | — |
## Checkpoint Log
- [YYYY-MM-DD] Plan creation started
```

If `state.md` already exists, update it to reflect plan phase.

### Step 3: Interview the User

**This is the most important step. Do not skip or rush it.**

Resolve all ambiguities through an iterative interview using `AskUserQuestion`. The goal is to capture every decision needed to produce a complete plan.

**Interview topics** (adapt to the feature):
- **Existing context pointers**: Are there specific Slack threads, Jira tickets, Confluence docs, or codebase files I should read before planning? The user often knows exactly where the relevant discussion or prior art lives — ask first, search later.
- **Scope**: What's in? What's explicitly out? What's "nice to have" vs required?
- **Users**: Who uses this? What are their key workflows?
- **Technical constraints**: Target repo, existing patterns to follow, performance requirements
- **Dependencies**: What must exist first? What teams need to be consulted?
- **Risks**: What could go wrong? What's the blast radius of failure?
- **Timeline**: Any hard deadlines? What's driving the urgency?
- **Success criteria**: How do we know this is done? How do we know it's working?

**Interview rules**:
- Ask up to 4 questions at a time (respects `AskUserQuestion` limits)
- Continue iterating until all ambiguities are resolved — there is no limit on rounds
- If the user says "whatever you think is best", provide your recommendation and get explicit confirmation
- If research/analysis artifacts exist, reference specific findings when asking questions
- Don't ask questions that are already answered in `research.html` or `analysis.html` when present, with Markdown fallbacks for legacy plans

### Step 4: Create the Plan

Read `context/standards/html-plan-standard.md` (the Artifact Format Standard) before writing the plan. Plans default to **Markdown-first** per that standard.

Produce `context/plans/active/<plan-name>/plan.md` as the primary plan artifact. Use heading hierarchy for navigation, tables for facts, fenced code blocks for commands/contracts, and inline ASCII or Mermaid diagrams for simple data flow.

Generate `context/plans/active/<plan-name>/plan.html` as an **optional visual companion** ONLY when the plan has substantial visual content the MD can't carry well — multi-arrow SVG architecture diagrams, dense mockups, color-coded risk matrices, side-by-side comparisons. When you do generate the HTML companion, follow the implementation-plan pattern from `https://thariqs.github.io/html-effectiveness/16-implementation-plan.html`. When the plan is mostly prose + tables, skip the HTML — the MD is enough.

The plan must include:
- **Overview**: What this is, why it matters, current state
- **Clarifications table**: Every decision made during the interview
- **User stories**: Concrete workflows per user type
- **Scope**: In-scope, out-of-scope, stretch goals
- **Risk assessment**: Risks with severity, likelihood, and mitigations
- **Work breakdown**: vertical-slice work items with blocking edges, target repo, validation, and exit criteria — drafted per "Drafting Work Items" below
- **Repo context**: linked `repo-context.html`, relevant repos/services, adjacent dependencies, repo-specific rules read, and validation profiles
- **PR breakdown timeline**: milestone-style slices modeled after the HTML implementation-plan example
- **Architecture/data-flow diagram**: inline SVG when the plan touches services, data flow, queues, APIs, UI/backend boundaries, or deployment flow
- **Scalability plan**: scale assumptions, bounds, and verification method
- **Exception-handling plan**: typed/narrow failures, retryability, fallback semantics, telemetry, and failure-path tests
- **Observability plan**: metrics/logs/traces, alerts, dashboards, owner/runbook expectations
- **Design decisions**: Key choices with rationale
- **Open questions**: Anything that needs codebase exploration in the target repo

#### Drafting Work Items (lean toward vertical slices)

Prefer tracer-bullet work items **where feasible** — vertical slices are the default choice, not a mandate. When a work item can be cut either way, it should be vertical; when a vertical slice isn't feasible, don't force it.

- A vertical slice cuts a narrow but **complete** path through every layer it touches (schema, API, UI, tests) — vertical, not a horizontal slice of one layer.
- A completed slice is demoable or verifiable on its own.
- Slices can compose: several work items may together form one vertical slice, just as all work items together form the full feature. When you split a slice, give the group a verifiable end point and wire the pieces with blocking edges.
- Each work item is sized to fit a single fresh context window — one PR, one implementation session.
- Any prefactoring lands first, as its own work item.
- Give each work item its **blocking edges** — the other work items that must complete before it can start. A work item with no blockers can start immediately.

**Wide refactors are the exception to vertical slicing.** A wide refactor is one mechanical change — rename a column, retype a shared symbol — whose blast radius fans across the whole codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Don't force it into a tracer bullet; sequence it as **expand–contract**:

1. **Expand**: add the new form beside the old so nothing breaks.
2. **Migrate**: move call sites over in batches sized by blast radius (per package, per directory), each batch its own work item blocked by the expand — CI stays green batch to batch because the old form still exists.
3. **Contract**: delete the old form once no caller remains, in a work item blocked by every migrate batch.

When even the batches can't stay green alone, keep the sequence but let them share an integration branch that all block a final integrate-and-verify work item — green is promised only there.

### Step 5: Create the Handoff Prompt

Produce `context/plans/active/<plan-name>/handoff.md` using the handoff template from `references/handoff-template.md`.

The handoff prompt is a self-contained document designed to be pasted into a Claude Code session in the target repo. It contains:
- Strategic context (what, why, key decisions) — so the implementation session doesn't need to re-derive intent
- User stories and acceptance criteria — concrete definition of done
- Work breakdown with PR-level scope — ready for implementation planning
- Decisions locked in during refinement — prevents re-opening settled questions
- Open technical questions — things that need codebase exploration
- Progress tracking section — tells the implementing agent where and how to write back progress
- Suggested next step: open `plan.md` (or `plan.html` if a visual companion was generated), paste/use `handoff.md` in the target repo, and begin codebase exploration for the open technical questions

**Template variables to fill in**:
- Replace `[COMMAND_CENTER_PATH]` with the absolute path to the command center repo root (read from the current working directory)
- Replace `[PLAN_NAME]` with the plan name from Step 1

### Step 6: Update State and Present

1. Update `state.md`:
   - Set phase to `completed`
   - Log the completion timestamp
2. Present a summary to the user:
   - HTML plan path and how to open it locally
   - Plan overview (2-3 sentences)
   - Key decisions made
   - Work breakdown summary (number of PRs, estimated scope)
   - Next step: copy `handoff.md` to the target repo
3. **Offer the implementation path** (when the plan has a PR-level breakdown): the **canonical** way to implement is the autonomous `plan-to-workflow` skill — it turns the breakdown into a runnable Workflow whose every PR runs `worktree → implement → E2E → review-gauntlet → ship`. Mention it: "To implement, run `/plan-to-workflow <plan-dir>` for an autonomous Workflow, or drive it interactively with `plan-implement → review-gauntlet → ship` (the fallback over the same stages)." See `../plan-to-workflow/references/orchestration-model.md`.

## Key Principles

- **Interview depth over speed.** A 15-minute interview saves days of wrong-direction implementation. Don't rush it.
- **Vertical slices where feasible, PR-level granularity always.** Lean toward tracer bullets — complete, demoable paths through the stack — but don't force one when it isn't feasible; a group of work items can form the slice together. Every item still maps to a single PR. Vague items like "implement the feature" and gratuitously horizontal items like "build all the endpoints" are both useless.
- **The handoff is the product.** The plan is for the user. The handoff is for the implementation session. Both must be complete and self-contained.
- **HTML is the plan surface.** Use Markdown only as a short compatibility/index file when another skill expects it.
- **Reference the evidence.** When making claims in the plan, reference findings from `research.html` and `analysis.html`, using Markdown fallbacks only for legacy plans. Don't assert things that weren't established during research.
- **Decisions are final.** Once captured in the clarifications table, decisions don't get re-opened in the handoff. The implementation session should not re-litigate what was decided here.

## Important Notes

- **This is a principal engineer.** Plans should be at the architecture level, not the code level. Focus on what and why, not how (the implementation session handles how).
- **Use `AskUserQuestion` for all clarification.** Never assume. If something could go two ways, ask.
- **The target repo may be different.** The handoff prompt will be used in a different Claude Code session, possibly a different codebase. It must be self-contained.
