---
name: confluence-review
description: Read and critically summarize a Confluence document. Surfaces key decisions, gaps, open questions, and suggests review questions.
metadata:
  workbench.argument-hint: "<page title or URL>"
---

# Confluence Review

Read a document and provide a structured, critical summary that enables fast decision-making.

Confluence spaces are defined in `config.yaml` under `confluence.spaces`.

## Input

The user will provide one of:
- A Confluence page URL
- A page title and space name
- A search query to find the right doc

## Process

### Step 1: Find and Fetch the Document

- If given a URL, extract the page ID and use `mcp__claude_ai_Atlassian__getConfluencePage`.
- If given a title/space, use `mcp__claude_ai_Atlassian__searchConfluenceUsingCql`.
- If the search returns multiple results, list them and ask which one.

### Step 2: Read the Full Document

Fetch the page content. If it references child pages or linked pages essential to understanding, fetch those too (up to 3 additional pages).

### Step 3: Check Comments

Use `mcp__claude_ai_Atlassian__getConfluencePageFooterComments` and `mcp__claude_ai_Atlassian__getConfluencePageInlineComments`. Comments often contain objections, clarifications, or decisions not reflected in the doc body.

### Step 4: Present the Summary

If saving or sharing the review, read `context/standards/html-plan-standard.md` and create `confluence-review.md` as the primary artifact (review summaries are Markdown-first per the standard). Generate a `confluence-review.html` companion only when the review reproduces structural elements of the source page that lose meaning in MD (deeply nested diagrams, embedded interactive widgets).

```
## Document: "Title"
**Space**: X | **Author**: Y | **Last Updated**: Z

### TL;DR
(2-3 sentences)

### What It Proposes
(Structured summary of the main content)

### Key Tradeoffs
- Tradeoff 1: chose X over Y because Z

### Open Questions / Gaps
- Things the doc doesn't address
- Missing sections (rollback plan, monitoring, migration path)

### Comments & Discussion
- Notable comments from reviewers
- Unresolved disagreements

### Questions You Should Raise
(2-4 specific questions based on the content and gaps)
```

## Important Notes

- Think critically. What would you push back on? What's missing?
- Check for: error handling, scalability, migration paths, rollback plans, monitoring, security.
- If the doc is an RFC or design doc, evaluate whether it's ready for approval.
