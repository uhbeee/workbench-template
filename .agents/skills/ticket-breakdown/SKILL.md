---
name: ticket-breakdown
description: Decompose a Jira epic or story into estimated subtasks including hidden work. Markdown-first saved artifacts (subtask lists are mostly tables/bullets); HTML companion only when the breakdown has substantial visual content (timeline SVG, dependency graph). Uses calibration data for realistic estimates. Optionally creates subtasks in Jira.
metadata:
  workbench.argument-hint: "<ticket-id>"
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Ticket Breakdown

Decompose a Jira epic or story into estimated implementation subtasks, including the hidden work that people always forget.

## Input

The user provides a Jira ticket ID. Optionally they may specify:
- Whether to create subtasks in Jira (default: no, just show the plan)
- Focus area (if only part of the epic needs decomposition)

## Process

### Step 1: Gather Full Context

1. Fetch the ticket using `mcp__claude_ai_Atlassian__getJiraIssue`
2. Read linked Confluence docs if any are referenced
3. Check for linked tickets (dependencies, related work)
4. Search Slack for recent discussion about this ticket
5. If the ticket, links, branch names, or current directory imply affected repos/services, invoke the `repo-context` skill. Use its bundled helper for deterministic output:
   - `python3 <workbench-root>/.agents/skills/repo-context/scripts/repo_context.py explain --repo <repo> --include-adjacent`
   - or `python3 <workbench-root>/.agents/skills/repo-context/scripts/repo_context.py explain --service <service> --include-adjacent`
   - or `python3 <workbench-root>/.agents/skills/repo-context/scripts/repo_context.py explain --current --include-adjacent`
   Use this to identify adjacent repos, validation profiles, App Insights hints, and repo-specific rule entrypoints before estimating.

### Step 2: Understand the Scope

Identify: what needs to be built/changed, which systems/repos are affected, who else is involved, what's unclear.

Record repo-context output in the breakdown when saved: primary/context/optional repos, services, product flows, repo-specific rules to read, and validation profiles. If a target repo has an instruction directory, count reading the relevant instructions as part of hidden/context-gathering work.

### Step 3: Decompose into Subtasks

Break into all categories:

**Implementation tasks**: discrete code changes, DB changes, API changes, UI changes

**Quality tasks**: unit tests, integration tests, manual testing

**Coordination tasks**: design review, Slack discussions, cross-team coordination

**Hidden work** (always include): context gathering, PR creation, review cycles (1-2 rounds), merge conflicts, deploy + verification, documentation

### Step 4: Estimate Each Subtask

1. Read `context/calibration.md` for calibrated multipliers and pace factor
2. Assign raw hour estimates, classify familiarity, note which repo
3. Apply appropriate multiplier
4. Apply pace factor if below 1.0

### Step 5: Produce the Breakdown

If the breakdown is being saved, shared, used as an implementation plan, or is large enough that the user will review it later, read `context/standards/html-plan-standard.md` and produce an HTML-first breakdown artifact named `ticket-breakdown.html` or `<ticket-id>-breakdown.html`. Use a concise Markdown summary only for chat or Jira compatibility.

```
## Ticket Breakdown: [TICKET-ID] — [Title]

### Context
- Epic/Story: [title]
- Systems affected: [repos]
- Open questions / Dependencies

### Subtask Breakdown
| # | Subtask | Category | Raw Est | Multiplier | Adjusted | Notes |
|---|---------|----------|---------|------------|----------|-------|

### Summary
- Raw total / Adjusted total / Calendar days / Confidence range

### Risks
- [Risk that could blow up the estimate]

### Recommended Sequencing
1. Start with X because...
```

### Step 6 (Optional): Create in Jira

If the user asks, create subtasks via `mcp__claude_ai_Atlassian__createJiraIssue`, link to parent, and set estimates.

## Important Notes

- The "hidden work" section is non-negotiable.
- If the ticket is vague, flag it as "needs refinement" and estimate the refinement work.
- Cross-repo changes multiply complexity.
- Note the calibration category for each subtask so actuals can be tracked later.
