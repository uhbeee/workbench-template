---
name: meeting-prep
description: Gather context for an upcoming meeting from Jira, Confluence, and Slack. Produces a brief with background, open questions, and talking points.
metadata:
  workbench.argument-hint: "<meeting topic>"
---

# Meeting Prep

Gather all relevant context for an upcoming meeting so you walk in informed and prepared.

Jira projects are defined in `config.yaml` under `jira.projects`. Confluence spaces are defined in `config.yaml` under `confluence.spaces`.

## Input

The user will provide:
- Meeting topic or name (required)
- Optionally: Jira epic/ticket ID, Confluence doc, or specific questions they want answered

## Process

### Step 1: Search for Context

Based on the meeting topic, search across all available sources:

**Jira**: Use `mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql` to find related tickets across all configured Jira projects.

**Confluence**: Use `mcp__claude_ai_Atlassian__searchConfluenceUsingCql` to find related docs across all configured Confluence spaces.

**Slack**: Use `mcp__claude_ai_Slack_MCP__slack_search_public_and_private` to find recent discussions. Focus on the last 2 weeks.

### Step 2: Synthesize the Context

Pull together everything found into a coherent brief. Connect the dots between Jira tickets, design docs, and Slack discussions.

### Step 3: Present the Brief

If the brief is saved, shared, or longer than a quick chat answer, read `context/standards/html-plan-standard.md` and create `meeting-brief.md` as the primary artifact (text-heavy briefs are Markdown-first per the standard). Generate a `meeting-brief.html` companion only when the brief carries genuine visual content — an agenda diagram, a decision matrix with semantic colors, side-by-side mockups for design reviews.

```
## Meeting Brief: [Topic]

### Background
(2-4 sentences: what this meeting is about and the current state of things)

### Key Jira Tickets
- [TICKET-ID] Title — Status: X, Assignee: Y
  (1-line summary)

### Relevant Documents
- "Doc Title" (Confluence) — (1-line summary)

### Recent Slack Discussion
- Key points from #channel discussions
- Decisions already made
- Open disagreements or questions

### Current State / Open Questions
1. Question that's likely to come up
2. Decision that needs to be made
3. Risk or blocker to surface

### Your Talking Points
(2-4 opinionated points a principal engineer should contribute)
```

## Important Notes

- Talking points should be opinionated, not generic. "We should discuss the migration plan" is weak. "The migration plan doesn't address rollback — we need to define the point-of-no-return before proceeding" is strong.
- If the meeting is a recurring sync, look for patterns: what was discussed last time, what action items were assigned.
- Keep the brief to 1 page / 2 minutes of reading.
