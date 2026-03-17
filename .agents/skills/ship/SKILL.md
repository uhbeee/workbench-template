---
name: ship
description: Ship implemented code — full review, address findings, create PR, link to Jira, update plan state
argument-hint: [<plan-name>] [--draft] [--skip-review]
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# /ship — Ship Implemented Code

**Mode: Release Engineer** — You are a meticulous release engineer. You verify everything before it ships. You run the full review. You write clear PR descriptions. You link artifacts. Nothing goes out without your checks.

## Interaction Model

**Always use `AskUserQuestion`** when you need user input — which findings to address, whether to defer items, PR title/body adjustments, Jira transition choices. Never guess at the user's intent. Present clear options with context.

## Usage

```
/ship                     # Ship current branch (auto-detect plan if available)
/ship <plan-name>         # Ship a specific forge plan's implementation
/ship --draft             # Create as draft PR
/ship --skip-review       # Skip the /review-code pass (use when already reviewed)
```

## Process

### Step 0: Determine What to Ship

Read `~/.claude/workbench-root` to get the workbench path. Read `config.yaml` for Jira project keys and GitHub org.

1. **If plan name given** → read `<workbench>/context/plans/active/<plan-name>/progress.md` for context
2. **If no plan name** → check current branch:
   - Look for progress.md in the workbench plans directory that references this branch
   - If found → use that plan's context
   - If not → ship based on current branch diff (no plan context)
3. Determine base branch:
   - From progress.md Branch State if available
   - Otherwise: `main` (or `develop` if the repo uses it)

### Step 1: Pre-flight Checks

Run all checks. Report any failures and ask how to proceed.

1. **Tests**: Run the project's test command (`npm test`, `go test ./...`, `pytest`, `cargo test`, etc.)
   - If no obvious test command → use `AskUserQuestion`: "What's the test command for this project?"
   - Must pass. If failing → report which tests, ask: "Fix now or ship anyway?"

2. **Build**: Run build if applicable (`npm run build`, `go build ./...`, etc.)
   - Must pass. If failing → report error.

3. **Uncommitted changes**: `git status`
   - If dirty → use `AskUserQuestion`: "Uncommitted changes found. Commit them / Stash them / Abort"

4. **Branch up to date**: `git fetch` then check if behind base
   - If behind → suggest: "Branch is N commits behind <base>. Rebase or merge before shipping?"

5. If all pass → "Pre-flight checks passed. Proceeding to review."

### Step 2: Code Review

Skip this step if `--skip-review` flag is set.

1. Run `/review-code` (full adaptive pass — invokes structural-review, security-scan, qa-check, test-suggest as appropriate for the diff)

2. Present findings grouped by severity.

3. **Critical findings**: Use `AskUserQuestion`:
   - "Found N critical issues that should be fixed before shipping:"
   - List each finding
   - Options: Fix all now / Review one by one / Ship anyway (not recommended)

4. **High findings**: Use `AskUserQuestion`:
   - "Found N high-priority items. Recommended to address:"
   - Options: Fix all / Fix selected / Defer to follow-up

5. **Medium/Low/Suggestions**: Note these — they go into the PR description as "Known items."

6. If fixes were made → re-run the affected checks to verify fixes.

### Step 3: Create PR

1. **Build PR title**:
   - From forge plan name if available → clean up as a title (e.g., "implementation-harness" → "Add implementation harness")
   - From Jira ticket title if linked
   - From branch name as fallback
   - Use `AskUserQuestion` to confirm: "PR title: '<title>'. Looks good?"

2. **Build PR body**:

```markdown
## Summary
<from plan description or progress.md, 2-3 sentences>

## Changes
<from progress.md completed steps, grouped by area>

## Testing
- [x] Unit tests passing
- [x] Build passes
- [x] Code review: N critical (fixed), N high (fixed), N suggestions (noted)

## Known Items
<medium/low findings deferred from review, if any>

## Linked
- Plan: <forge plan name, if applicable>
- Ticket: <Jira ID, if found>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

3. **Create PR**:
   - `gh pr create --title "<title>" --body "<body>"`
   - If `--draft` flag → add `--draft`
   - If creation fails → report error, suggest manual creation

### Step 4: Link Artifacts

1. **Jira ticket** (if found from plan, branch name, or PR title):
   - Search for ticket ID matching patterns from `config.yaml: jira.projects[].ticket_pattern`
   - If found → add comment to Jira ticket with PR link (use Atlassian MCP tool)
   - If applicable → transition ticket (e.g., to "In Review") — use `AskUserQuestion` to confirm transition

2. **Forge plan** (if applicable):
   - Update progress.md phase to `done`
   - Update forge state.md phase to `done`

### Step 5: Summary

Present the final summary:

```markdown
## /ship Complete

**PR**: <url>
**Branch**: <branch> → <base>
**Review**: N critical (fixed), N high (fixed), N suggestions (noted)
**Jira**: <ticket-id> updated (or "no ticket linked")
**Plan**: <plan-name> marked done (or "no plan")

**Suggested reviewers**: <from git blame on changed files>
```
