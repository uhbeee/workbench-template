---
name: slack-catch-up
description: Scan Slack channels, DMs, and @mentions to surface what needs attention. Filters noise, prioritizes by urgency. Use after being away or to catch up mid-day.
metadata:
  workbench.argument-hint: "[channels] [time-window]"
---

# Slack Catch-up

Scan channels, DMs, and @mentions, then surface what needs attention — filtering out the noise.

The user's display name is defined in `config.yaml` under `user.slack_display_name`. Slack channels are defined in `config.yaml` under `slack.channels`.

## Input

The user may optionally specify:
- Specific channels to check (otherwise check all configured channels)
- A time window (otherwise default to last 8 hours)
- A topic to focus on

## Process

### Step 1: Check DMs and @Mentions First

Read `config.yaml` to get the user's Slack display name. Search for messages mentioning that name using `mcp__claude_ai_Slack_MCP__slack_search_public_and_private`.

For each DM or @mention found:
- Read the full thread
- Classify as: needs response, FYI, or already handled
- Note who sent it, when, and how urgent it appears

### Step 2: Read Channels

Read messages from channels defined in `config.yaml: slack.channels`.

Check in this priority order:

**High priority** (always check):
1. Operations channels — system/operational alerts
2. Product channels with "issues" in the name — customer-facing issues
3. Engineering channels — team discussions and PR reviews

**Medium priority** (check if time allows):
4. Remaining operations channels
5. Remaining product channels

**Low priority** (scan briefly):
6. General channels — company-wide

### Step 3: Identify Actionable Threads

For each channel, classify messages as:
- **Needs your response**: Someone asked a question, tagged you, or the topic is in your domain
- **FYI - Important**: Decisions made, announcements that affect your work
- **FYI - Noise**: Status updates, social chatter, things resolved without you

Only report the first two categories.

### Step 4: Read Important Threads

For threads identified as actionable or important, read the full thread context. Summarize:
- What's being discussed
- What's been decided (if anything)
- What's needed from you specifically

### Step 5: Present the Summary

```
## Slack Catch-up

### DMs and @Mentions
1. **DM from @person** — [summary]. Sent X hours ago. (needs response / FYI)
2. **@mention in #channel** — [context]. Thread has X replies.

### Needs Your Response
1. **#channel** — @person asked about [topic]. No resolution yet.
2. **#channel** — PR #NNN needs review, posted X hours ago.

### Important FYI
1. **#channel** — [service] deployed to production. No issues reported.

### Nothing Actionable
Channels with no actionable items: #general, ...
```

### Step 6: Offer to Respond

For DMs and threads needing a response, ask: "Want me to draft a response to any of these?"

## Important Notes

- DMs and @mentions always come first. Direct messages are highest signal.
- Never send a Slack message without explicit approval.
- Be aggressive about filtering. Reduce all channels + DMs to 3-5 actionable items.
- If there's an active incident, flag it immediately at the top.
- Prioritize by "what will have the most negative consequence if ignored."
