---
name: morning-triage
description: Scan DMs, @mentions, Slack channels, and Jira to create a prioritized daily plan. Run this every morning to start the day focused.
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Morning Triage

Scan all relevant channels, check DMs and @mentions, check Jira, and create a prioritized daily plan.

The user's display name is defined in `config.yaml` under `user.slack_display_name`. Slack channels are defined in `config.yaml` under `slack.channels`. Jira projects are defined in `config.yaml` under `jira.projects`.

## Process

### Step 1: Check DMs and @Mentions

**This is the highest priority step.** Before anything else:

1. Read `config.yaml` to get the user's Slack display name from `user.slack_display_name`.
2. Search for recent messages mentioning that display name using `mcp__claude_ai_Slack_MCP__slack_search_public_and_private`.
3. Also search with query: `to:me` or check DMs for unread messages.

For each DM or @mention found:
- Read the full thread using `mcp__claude_ai_Slack_MCP__slack_read_thread`
- Classify as: needs response, FYI, or already handled
- Note who sent it and how urgent it appears

### Step 2: Read Slack Channels

Read channels from `config.yaml: slack.channels` for messages from the last 24 hours. Focus on threads that are unresolved, need input, or signal something urgent.

Check channels in category order (operations first for incidents, then product, then engineering, then general). Use `mcp__claude_ai_Slack_MCP__slack_read_channel` for each channel.

### Step 3: Check Jira

Search for tickets that need attention using the project keys from `config.yaml: jira.projects`:

1. Tickets assigned to me that are in progress or to-do (use `searchJiraIssuesUsingJql` with all configured project keys)
2. Tickets updated in the last 24 hours in all configured projects
3. Any tickets in "Blocked" status

### Step 4: Check Yesterday's Plan and Weekly Plan

- Read `context/active/daily.md` for yesterday's plan (if the date in it is a previous day, it hasn't been archived yet). Identify anything that wasn't completed and should carry forward.
- Read `context/active/weekly.md` for this week's capacity state. Note remaining capacity and any items that are due this week.
- If no weekly plan exists, flag this and suggest creating one after the daily triage.

### Step 5: Get Today's Calendar

Check `context/active/calendar.md` for today's actual meeting schedule.
- If the file exists, use the real meeting hours and available hours for today.
- If the file is missing or outdated, suggest running `/calendar-sync` first.
- Note the best focus blocks (longest meeting-free stretches) for scheduling deep work.

### Step 6: Estimate and Prioritize

For each task identified (DMs, Jira tickets, carried items), create a quick time estimate:
- Read `context/calibration.md` for calibrated multipliers and pace factor
- Apply calibrated multipliers if available, otherwise use defaults from `config.yaml: estimation.multipliers`
- Keep estimates lightweight at this stage — gut feel with the calibrated minimum multiplier
- Sum up the total estimated hours

Check against today's real capacity (from calendar):
```
Meetings today: Xh (from calendar-sync)
Available today: Yh (6h minus meetings, adjusted for pace factor)
Total estimated: Zh
Status: [fits / tight / overcommitted]
Best focus block: HH:MM - HH:MM (Xh uninterrupted)
```

If overcommitted, explicitly flag which items should be deferred or delegated.

### Step 7: Archive Yesterday and Create Today's Plan

Before creating today's plan:
1. Check if `context/active/daily.md` exists and its date header is from a previous day.
2. If so, move it to `context/archive/YYYY/MM/daily/YYYY-MM-DD.md` (creating directories as needed).
3. Then create a fresh `context/active/daily.md`.

Structure the plan with:
1. **Capacity Today** — available hours after meetings, committed hours, remaining.
2. **DMs and @Mentions** — anything that needs a direct response, with time estimates. Listed first since these are people waiting on you specifically.
3. **Top Priorities** (max 5) — ordered by impact. For each item: WHY it matters, WHO is affected, and estimated hours.
4. **Carried Forward** — incomplete items from yesterday, if still relevant, with estimates.
5. **Slack Threads Needing Response** — specific threads where input is needed.
6. **Meetings Today** — if mentioned in Slack or known.

If the total estimated hours exceed available capacity, call this out explicitly and recommend what to defer.

Keep `context/active/daily.md` as the automation source of truth. If the daily plan is meant to be reviewed or shared beyond the session, also create/update `context/active/daily.html` using `context/standards/html-plan-standard.md` as a companion view. Do not replace `daily.md`.

### Step 8: Present the Summary

Give a brief verbal summary:
- X DMs / @mentions waiting for your response
- Y items from channels need attention
- Z Jira tickets are active
- W items carried from yesterday
- Total estimated: Xh against Yh available
- **Capacity verdict**: [fits / tight / overcommitted — need to cut Z]
- Here's the recommended priority order and why

Ask if the priorities look right or if anything should be reordered or deferred.

## Important Notes

- DMs and @mentions come first. Someone directly reaching out to you is always higher signal than channel noise.
- Be concise. This should take under 2 minutes to read.
- Lead with action items, not status reports.
- If something is genuinely urgent (incident, blocked deployment, customer escalation), flag it at the very top before the normal plan.
- Don't include noise — skip channels with nothing actionable.
