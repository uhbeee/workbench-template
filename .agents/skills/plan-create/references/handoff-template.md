# Implementation Handoff: [Feature Name]

> This prompt contains the strategic context for implementing [feature name]. It was produced in the command-center workspace after research, critical analysis, and planning. Paste this into a Claude Code session in the target repo to begin implementation.

**Plan artifact**: `[COMMAND_CENTER_PATH]/context/plans/active/[PLAN_NAME]/plan.html`

## Strategic Context

**What**: [1-2 sentences — what are we building]

**Why**: [1-2 sentences — business/technical motivation]

**Key decisions already made**:
- [Decision 1]: [Choice] — [brief rationale]
- [Decision 2]: [Choice] — [brief rationale]

## User Stories

### [User Type 1]

- **[Flow 1]**: [Step-by-step description]
- **[Flow 2]**: [Alternative flow or edge case]

### Acceptance Criteria

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

## Work Breakdown

| # | PR Scope | Dependencies | Size |
|---|----------|--------------|------|
| 1 | [What this PR does; mirror the PR timeline in plan.html] | None | S/M/L |
| 2 | [What this PR does] | PR 1 | S/M/L |

## Decisions Locked In

These were resolved during planning. Do not re-open:

| Decision | Choice | Rationale |
|----------|--------|-----------|
| [Decision 1] | [Choice] | [Why] |

## Open Technical Questions

These need codebase exploration before implementation:
- [ ] [Question 1 — what to look for]
- [ ] [Question 2 — what pattern to verify]

## Out of Scope

Do not implement these (documented for awareness):
- [Item 1] — [reason]
- [Item 2] — [reason]

## Progress Tracking

As you implement, track progress in the command center so that future sessions can resume seamlessly.

**Where**: `[COMMAND_CENTER_PATH]/context/plans/active/[PLAN_NAME]/progress.md`

**When to update**:
- After completing each step (update Progress Overview table + add Step Details entry)
- When deviating from the plan (add a Decision Changelog entry: DC-001, DC-002...)
- When hitting a blocker (add to Active Blockers table)
- On every natural stopping point (add a Session Log entry with "next session should" instructions)

**How to initialize** (if `progress.md` doesn't exist yet):

Create it with these sections:
1. **Summary** — plan name, target repo, command center path, dates, overall status
2. **Progress Overview** — step-status table (copy steps from the plan.html PR breakdown timeline)
3. **Active Blockers** — table with ID, severity, blocked steps, identified date, description
4. **Iteration Summary** — brief narrative of how the plan evolved during implementation
5. **Decision Changelog** — append-only table (DC-001, DC-002...) with: step, original decision, revised decision, rationale. Later reversals get new entries referencing the original.
6. **Step Details** — per-step notes: files created/modified, unexpected findings, verification results
7. **Session Log** — newest-first. Each entry: what was done, what's incomplete, "next session should" instructions, codebase state

**Rules**:
- Session Log and Decision Changelog are append-only (newest first for sessions, sequential for decisions)
- Keep the Progress Overview table in sync with Step Details — the table is the quick-scan view
- Update the Summary's "Last updated" and "Overall status" on every write
- Include file paths in Step Details so future sessions know what was touched

## Suggested Next Step

Open `plan.html`, then start exploring the codebase to answer the open technical questions above.
