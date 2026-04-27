---
name: plan-sync
description: Synchronize a planning doc with the latest changes in the repository.
argument-hint: [file]
---

# Plan sync

Update the planning doc with the latest changes in the repository. If user doesn't provide a doc, ask them to provide one.

Doc: $ARGUMENTS

## Workflow

1. If no doc is provided, ask the user to provide the path to the plan or pr-breakdown file.
   - For Cursor, use `AskQuestion` tool to ask the user questions.
   - For Claude Code, use `AskUserQuestion` tool to ask the user questions.

2. Read the provided doc and identify:
   - What PRs have been completed (check git history, merged branches)
   - What files have changed since the plan was created
   - Any discrepancies between planned and actual implementation

3. If there is a `HANDOFF.md` in the plan folder, read it to understand prior session context and incorporate any relevant notes into the updated docs. Clear stale handoff information that no longer applies (e.g., "next steps" that are now complete).

4. If there is a related `pr-breakdown.md` file, update that doc as well:
   - Mark completed PRs as "Completed"
   - Update file lists if implementations differ from plan
   - Add notes about any deviations from the original plan

5. If there is a related `plan.md` file, update that doc as well:
   - Update "Current state" section if applicable
   - Note any design decisions that changed during implementation

6. After updating the docs, commit the updated docs with message: `docs: sync planning docs with implementation`
