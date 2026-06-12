---
name: ship
description: Land implemented code — open the PR, monitor GitHub checks, merge, then clean up the worktree and local branch. Does NOT review (review-gauntlet is the authoritative review — run it first). Links Jira and updates plan state.
metadata:
  workbench.argument-hint: "[<plan-name>] [--draft] [--no-merge] [--no-cleanup]"
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# /ship — Land Implemented Code (open → monitor → merge → tidy)

**Mode: Release Engineer** — You land work that has already passed review. You open a clean PR, watch CI, merge when green, and leave no mess behind. **You do not review** — that is `review-gauntlet`'s job, and it must have run first (it is the single source of review truth; see `../plan-to-workflow/references/orchestration-model.md`).

This skill is the final stage of the canonical gate chain: `worktree → implement → E2E → review-gauntlet → **ship**`.

## Interaction Model

**Use `AskUserQuestion`** for irreversible/outward steps when run interactively — confirming the merge, Jira transitions, PR title/body. When invoked as the autonomous Workflow ship stage, proceed without nagging once checks are green and the PR is mergeable; still never merge a PR with red/required-but-pending checks.

## Usage

```
/ship                  # Land current branch (auto-detect plan if available)
/ship <plan-name>      # Land a specific plan's implementation
/ship --draft          # Open as draft PR, do not merge (implies --no-merge --no-cleanup)
/ship --no-merge       # Open + monitor only; stop before merging
/ship --no-cleanup     # Merge but keep the worktree + local branch
```

## Process

### Step 0: Determine what to ship
1. Read `~/.codex/workbench-root` / `~/.claude/workbench-root`; read `config.yaml` for Jira keys + GitHub org.
2. Plan name given → read `<workbench>/context/plans/active/<plan-name>/progress.md` (or the plan dir's `summary.md`/`pipeline.md`) for context. No plan → use the branch diff.
3. Resolve base/parent branch: from plan state if available; **for a stacked PR, the base is its PARENT branch, not the repo default.** Otherwise `develop` (or `main`).

### Step 1: Pre-flight (NOT a review)
1. **Confirm review happened.** Review is out of scope here. If there's no evidence `review-gauntlet` ran for this diff (no gauntlet result in the plan/pipeline, user didn't say so), STOP and say: "Run `/review-gauntlet` first — ship does not review." Do not substitute a review.
2. **Build/tests sanity** — a quick green check (the gauntlet already ran the real-data suites; this is just a guard against a dirty tree). If red → report, ask how to proceed.
3. **Working tree**: `git status`. If this PR's files are uncommitted, commit ONLY this PR's files (exclude `.claude/*`, `.coverage`, unrelated dirty paths). Never leave the work uncommitted.
4. **Branch freshness**: `git fetch`; if behind base, offer rebase/merge before opening.

### Step 2: Open the PR
1. **Title** — from plan name / Jira ticket / branch; confirm with `AskUserQuestion` when interactive.
2. **Body**:
   ```markdown
   ## Summary
   <from plan summary, 2-3 sentences>
   ## Changes
   <from progress/summary, grouped by area>
   ## Testing
   - [x] review-gauntlet GREEN (5-lens + invariant audit + CRAP gate)
   - [x] real-data E2E: <what ran live — testcontainers / live MCP+Runtime>
   ## Linked
   - Plan: <name> · Ticket: <Jira ID>
   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   ```
3. `gh pr create --base <parent-or-base> --head <branch> --title … --body …`. Add `--draft` if flagged. On failure → report + suggest manual.

### Step 3: Monitor GitHub
1. Poll `gh pr checks <pr>` (and `gh pr view <pr> --json mergeStateStatus,statusCheckRollup,reviewDecision`) until checks conclude.
2. Report check results. If any required check **fails** → STOP, surface the failing check, do not merge. If checks are merely pending → wait/poll (bounded), then re-report.

### Step 4: Merge (skip if `--draft`/`--no-merge`)
1. Merge only when: required checks GREEN and the PR is mergeable (no conflicts, required approvals satisfied per branch protection).
2. Interactive → `AskUserQuestion` confirm merge + method (squash/merge/rebase per repo convention). Autonomous → merge with the repo's default method once green.
3. `gh pr merge <pr> --squash` (or repo convention) `--delete-branch` if remote-branch deletion is wanted.

### Step 5: Post-merge cleanup (skip if `--no-cleanup` or not merged)
1. **Remove the worktree** — use the `worktree-remove` skill (guarded dry-run first) for this PR's feature worktree.
2. **Delete the local branch** — `git branch -d <branch>` (use `-D` only if you confirm it's merged). Prune the remote tracking ref if the remote branch was deleted on merge.
3. For a **stacked** PR, do NOT delete a branch that a child PR still targets — cleanup waits until dependents have re-pointed/merged.

### Step 6: Link artifacts
1. **Jira** (if found): comment the PR link; `AskUserQuestion` to confirm any transition (e.g. → In Review/Done).
2. **Plan**: update `progress.md`/`pipeline.md` + state to reflect merged + cleaned.

### Step 7: Summary
```markdown
## /ship Complete
**PR**: <url> — <merged | open | draft>
**Branch**: <branch> → <base/parent>
**Checks**: <green/failed/pending summary>
**Review**: review-gauntlet GREEN (ran in the prior stage)
**Cleanup**: worktree removed · local branch deleted (or "kept: --no-cleanup")
**Jira**: <ticket> updated (or "none") · **Plan**: <name> marked shipped (or "none")
```

## Non-negotiables
- **No review here.** If the gauntlet didn't run, stop and say so. Single source of review truth = `review-gauntlet`.
- **Commit only this PR's files**; never leave work uncommitted in the worktree.
- **Never merge on red/pending-required checks.**
- **Tidy after landing** — worktree + local branch — unless `--no-cleanup` or a child PR still depends on the branch.
