---
name: wrap-up
description: Update today's daily plan with current progress — mark completed items, update hours, and note what rolls forward. Lighter than the full end-of-day agent.
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Quick Progress Update

Update today's daily plan with current progress. Lighter than the full end-of-day agent.

## Process

1. Read `context/active/daily.md`
2. If the file doesn't exist, say so and stop
3. Ask the user: "Which items did you complete? Any notes to add?"
4. Based on their response:
   - Mark completed items with `[x]`
   - Update `## Capacity Today` committed/remaining hours
   - Add any notes to the `## Notes` section with a timestamp
   - Update `## End of Day` section with:
     - Completed count: X/Y items
     - Hours summary (if the user provides actual hours)
     - Items to roll forward (unchecked items)
5. Save the file

## Output

Show a brief summary: "Updated daily plan — X/Y items done, Zh remaining."
