---
name: jira-review
description: Pull a Jira ticket with linked docs, tickets, comments, and PRs. Produces an actionable summary with assessment and open questions.
metadata:
  workbench.argument-hint: "<ticket-id>"
---

# Jira Review

Pull a ticket and give a comprehensive, actionable summary.

Jira project keys and ticket patterns are defined in `config.yaml` under `jira.projects`.

## Input

The user will provide a Jira ticket ID (e.g., matching one of the patterns defined in `config.yaml: jira.projects[].ticket_pattern`).

## Process

### Step 1: Fetch the Ticket

Use `mcp__claude_ai_Atlassian__getJiraIssue` to get the full ticket details.

### Step 2: Check Linked Items

From the ticket data:
- Identify any **linked Jira tickets** (blocks, is-blocked-by, relates-to). Fetch key linked tickets for context.
- Identify any **linked Confluence pages**. If found, read them using `mcp__claude_ai_Atlassian__getConfluencePage`.
- Check for **remote links** (GitHub PRs) using `mcp__claude_ai_Atlassian__getJiraIssueRemoteIssueLinks`.

### Step 3: Read Comments

Summarize the comment thread, highlighting:
- Decisions or agreements
- Open questions with no answer
- Scope changes from the original description

### Step 4: Present the Summary

```
## [TICKET-ID] Title
**Status**: X | **Assignee**: Y | **Priority**: Z

### What This Is About
(1-3 sentences)

### Key Decisions (from comments)
- Decision 1
- Decision 2

### Open Questions
- Question with no answer yet
- Ambiguity in requirements

### Linked Context
- [TICKET-ID] Related ticket (status: X)
- Confluence: "Doc Title" — (1-line summary)
- PR #NNN — (status: open/merged)

### Acceptance Criteria
(From the ticket, or flag if missing)

### Assessment
(Is it well-defined? Missing info? Ready to work on? Blocked?)
```

## Important Notes

- If acceptance criteria are missing or vague, explicitly flag this.
- If the ticket references other tickets in its description, fetch those too.
- Keep the summary scannable. Bullet points, not paragraphs.
