---
name: capacity
description: Show remaining capacity today and this week by reading daily and weekly plans. Flags overcommitment. Use when checking if there's room for more work.
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Quick Capacity Check

Show remaining capacity today and this week. Flag overcommitment.

## Process

1. Read `context/active/daily.md` — extract committed hours and remaining hours
2. Read `context/active/weekly.md` — extract weekly committed vs available hours
3. Calculate:
   - Hours remaining today (available minus committed)
   - Hours remaining this week (weekly available minus weekly committed)
   - Overcommitment flag if committed > available at either level

## Output Format

```
**Today**: Xh committed / Yh available → Zh remaining [or OVERCOMMITTED by Zh]
**This week**: Xh committed / Yh available → Zh remaining [or OVERCOMMITTED by Zh]
```

If either plan file is missing, say so and suggest running the appropriate agent.
