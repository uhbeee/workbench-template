---
name: pr-context
description: Gather full context for a PR — Jira ticket, design doc, Slack discussion. Produces a Markdown-first informed review brief so code review catches intent-vs-implementation gaps. Generates an HTML companion only when the brief has substantial visual content (architecture diagrams, side-by-side mockups).
metadata:
  workbench.argument-hint: "<PR number>"
---

# PR Context

Gather the full picture around a pull request — not just the code, but the WHY behind it.

The user's GitHub org and repositories are defined in `config.yaml` under `github.org` and `github.repositories`. Jira ticket patterns are in `config.yaml` under `jira.projects[].ticket_pattern`.

## Input

The user will provide:
- A PR number (required)
- Optionally: the repository name

## Process

### Step 1: Get PR Details from GitHub

Use `gh pr view <number>` (via Bash) to get: title, description, author, branch name, files changed, comments and review status.

After the repo is known, invoke the `repo-context` skill before writing the review brief. Use its bundled helper for deterministic output:

```bash
python3 <workbench-root>/.agents/skills/repo-context/scripts/repo_context.py explain --repo <repo> --include-adjacent
```

Use the output to capture adjacent services/repos, product flows, validation profiles, observability hints, and repo-specific rule entrypoints. If a review worktree will be created, read the target repo rules before reviewing code.

### Step 2: Find the Jira Ticket

Look for a Jira ticket ID in the PR title, description, or branch name (patterns from `config.yaml`). If found, fetch it.

### Step 3: Find Related Design Docs

From the Jira ticket, check for linked Confluence pages. Fetch if found.

### Step 4: Find Slack Discussion

Search Slack for the PR number or Jira ticket ID in engineering channels.

### Step 5: Present the Full Context

If saving or sharing the review brief, read `context/standards/html-plan-standard.md` and create `pr-context.html` as the primary artifact. Use the structure below inside the HTML page. Markdown/plain text is only for a short chat summary or PR comment paste format.

```
## PR #NNN: Title
**Author**: X | **Repo**: Y | **Status**: Z

### What This PR Does
(1-3 sentences from PR description + Jira ticket)

### Why It Exists
(From Jira: what problem it solves, business context)

### Design Context
(From Confluence: agreed approach, constraints)

### Slack Discussion
(Relevant discussion, concerns raised, alternatives considered)

### Files Changed
(High-level summary, concerning patterns)

### Repo Context
(Relevant repos/services, adjacent dependencies, repo-specific rules, validation profiles, and observability hints from repo-context)

### Review Considerations
(What to focus on during review: design alignment, edge cases, Slack concerns, PR size)
```

## Important Notes

- The point is to make code review INFORMED. Context prevents superficial reviews.
- If no Jira ticket is found, flag this.
- If the PR is large (20+ files), suggest reviewing in logical chunks.
- After running this, the user will likely switch to a worktree to review the code.
