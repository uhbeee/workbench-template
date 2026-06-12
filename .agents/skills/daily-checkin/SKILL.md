---
name: daily-checkin
description: Mid-day progress check against the daily plan. Scans for new DMs, checks capacity, and helps reprioritize if needed.
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Daily Check-in

Review progress against today's plan and help maintain focus.

The user's Slack display name is defined in `config.yaml` under `user.slack_display_name`. Slack channels are defined in `config.yaml` under `slack.channels`.

## Process

### Step 1: Read Today's Plan

Read the daily plan file at `context/active/daily.md`.

If no plan exists, say so and suggest running `/morning-triage`.

### Step 2: Assess Progress and Time

Look at the checkboxes and time estimates in the plan:
- Count completed vs total items
- Compare estimated hours to how the day is actually going
- If the user completed a task, ask how long it actually took and update the plan with actuals
- Identify what's still open and how many estimated hours remain
- Check against today's remaining capacity: "You have Xh left and Yh of work remaining"
- Note the highest-priority incomplete item

Also read the weekly plan (`context/active/weekly.md`) for weekly context:
- Are we on track for the week overall?
- Is anything due this week that hasn't been started yet?

### Step 3: Quick Check for DMs and @Mentions

Read `config.yaml` to get the user's Slack display name from `user.slack_display_name`. Search for recent messages mentioning that name using `mcp__claude_ai_Slack_MCP__slack_search_public_and_private`. Check if any new DMs or @mentions have come in since the morning triage.

Also do a lightweight check of highest-priority channels from `config.yaml: slack.channels` — check operations channels first (any incidents?), then product channels (any new urgent issues?), then key engineering channels (any threads waiting on a response?).

Only report if there's something that changes priorities.

### Step 4: Present the Check-in

Format:
```
Progress: X/Y items completed
Time: Xh used / Yh estimated remaining / Zh available today
Weekly: Xh committed / Yh remaining this week
Unanswered DMs/@mentions: N (if any new ones)
Top incomplete: [item] — WHY this matters: [reason] — est: Xh
New from Slack: [anything urgent, or "nothing new"]
```

Then ask:
- "Want to keep the current priority order, or has something changed?"
- If estimated remaining hours exceed available hours today: "You're overcommitted by Xh. What should move to tomorrow?"
- If items are falling behind, ask if they should be deprioritized, delegated, or if there's a blocker to address.
- If a completed task took significantly longer than estimated, note the ratio for calibration.

### Step 5: Update the Plan

If priorities change based on the conversation, update the daily plan file with:
- Reordered items
- New items added (including new DMs/mentions)
- Items explicitly deprioritized (move to a "Deferred" section, don't delete)

## Tone

Direct and supportive, not nagging. The goal is to help maintain focus, not to judge. If nothing's been checked off, ask "what's been taking up your time?" — there's usually a good reason (meetings, unexpected incident, etc.) and the plan should adapt.

## Important Notes

- Never guilt-trip about incomplete items. Reprioritizing IS progress.
- If 3+ items carry forward for multiple days, flag this pattern and suggest whether the items are actually important or should be dropped.
- Keep the check-in under 30 seconds to read.
