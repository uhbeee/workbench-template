---
name: status-report
description: Generate a stakeholder-ready status update organized by quarterly goals. Pulls from weekly plan, daily plans, and Jira. Markdown-first by default for agent / engineer readability; generates an HTML companion when the report is going to a non-technical stakeholder audience or has substantial visual content (status matrix with semantic colors, charts). Provides Slack/email paste formats when requested.
metadata:
  workbench.argument-hint: "[format] [audience]"
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Status Report Generator

Produce a concise stakeholder-ready status update from the week's work, organized by quarterly goals.

## When to Run

End of week, or when you need to report status to management or cross-team stakeholders.

## Input

The user may optionally specify:
- Format preference: Slack post or email
- Audience: manager, skip-level, cross-team
- Time period: this week (default), last N days, or custom range

## Process

### Step 1: Gather Context

1. Read `context/active/weekly.md` for committed work and progress
2. Read `context/active/goals.md` for quarterly goal mapping
3. Read this week's daily plans (active + archived) for detailed completion data
4. Read `config.yaml` for Jira project keys

### Step 2: Pull Jira Updates

For each Jira project defined in `config.yaml: jira.projects[]`:
- Search for tickets updated this week assigned to or involving the user
- For key tickets, read full details with `mcp__claude_ai_Atlassian__getJiraIssue`

### Step 3: Map to Goals

Group all completed and in-progress work by quarterly goal:
- For each goal in `context/active/goals.md`, list relevant work done this week
- Flag any goals with zero progress this week
- Flag any at-risk goals

### Step 4: Generate the Report

If the report is saved, shared as a standalone file, or meant for leadership review, read `context/standards/html-plan-standard.md` and create `status-report.html` as the primary artifact. Use the structure below inside the HTML page with a top summary band, goal status table, risk callouts, and copy/export sections for Slack or email when useful.

```
## Status Update — Week of YYYY-MM-DD

### [Goal 1 Name]
**Status**: On track / At risk / Behind
- Completed: [item] (TICKET-123)
- In progress: [item] — expected completion [date] (TICKET-456)
- Blocker/risk: [description]

### [Goal 2 Name]
...

### Other Work
- [Items not tied to a quarterly goal]

### Key Decisions Made
- [Important decisions from this week]

### Blockers and Risks
- [Blocker] — impact: [what's affected], mitigation: [plan]

### Next Week Focus
- [Top 2-3 priorities for next week]
```

### Step 5: Format for Delivery

If Slack format: produce Slack-friendly markdown/plain text as the delivery version. Offer to post directly.

If email format: produce clean markdown or plain text suitable for pasting into an email.

## Important Notes

- Lead with what matters to the audience. Managers care about goal progress and risks. Skip-levels care about strategic alignment.
- Be honest about blockers. Surfacing problems early is a feature, not a bug.
- Don't pad the report. If it was a light week, say so.
- Link to Jira tickets so readers can drill in.
- Never send without explicit user approval.
