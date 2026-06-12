---
name: end-of-day
description: Review what happened today, capture unanswered DMs, update daily plan with completion data, and set up tomorrow. Run at the end of each work day.
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# End of Day

Review what happened today, capture what's rolling forward, and set up tomorrow for success.

The user's Slack display name is defined in `config.yaml` under `user.slack_display_name`. Slack channels are defined in `config.yaml` under `slack.channels`.

## Process

### Step 1: Read Today's Plan

Read the daily plan at `context/active/daily.md`.

### Step 2: Assess Completion

Review each item:
- What got done? Mark completed items.
- What didn't get done? Ask briefly why (got pulled into something else, blocked, deprioritized).
- Were there unplanned items that took up time? Capture them.

### Step 3: Check for Unanswered DMs

Read `config.yaml` to get the user's Slack display name from `user.slack_display_name`. Search for any DMs or @mentions of that name from today using `mcp__claude_ai_Slack_MCP__slack_search_public_and_private`. Flag any that still need a response — these shouldn't roll to tomorrow without being acknowledged.

### Step 4: Quick Slack Check

Do a brief scan of high-priority channels from `config.yaml: slack.channels` for anything that came in late in the day. Check operations channels first (alerts, incidents), then product channels (urgent issues), then key engineering channels.

Flag anything that needs attention tomorrow.

### Step 5: Update Today's Plan

Update the daily plan file with an "End of Day" section:

```markdown
## End of Day
- **Completed**: X/Y planned items
- **Unplanned work**: [list anything that came up unexpectedly]
- **Unanswered DMs**: [any DMs that still need a response]
- **Rolling forward**:
  - [ ] Item 1 (reason it didn't get done)
  - [ ] Item 2
- **Blockers**: [anything blocking progress]
- **Notes for tomorrow**: [anything to remember]
```

### Step 6: Summary

Present a quick verbal summary:
- What was accomplished
- Any unanswered DMs/messages that need attention
- What's rolling forward and why
- Any overnight risks (deployments, pending incidents, etc.)
- Suggested first priority for tomorrow morning

## Important Notes

- This is not a performance review. It's a handoff from today-you to tomorrow-you.
- Unanswered DMs get special attention — leaving someone on read overnight is worse than a late reply.
- If something rolled forward for 3+ days, flag the pattern. Either it's not actually important (drop it) or something is blocking it (address the blocker).
- Keep it under 1 minute to read.
- If there were wins today (shipped a feature, unblocked the team, caught a bug in review), note them. Visibility into your own impact matters.
