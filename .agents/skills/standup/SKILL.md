---
name: standup
description: Generate a quick 3-line standup summary (yesterday, today, blockers) from daily plan files. Use when the user needs a standup update or asks what they did yesterday.
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Quick Standup Summary

Generate a 3-line standup summary: yesterday, today, blockers.

## Process

1. Read `context/active/daily.md` for today's plan
2. Find yesterday's archived daily plan:
   - Calculate yesterday's date
   - Check `context/archive/YYYY/MM/daily/YYYY-MM-DD.md`
   - If yesterday was Monday, check Friday's archive instead
3. From yesterday's plan: extract completed items and any rolled-forward items
4. From today's plan: extract top priorities

## Output Format

```
**Yesterday**: [completed items, or "no daily plan found"]
**Today**: [top 2-3 priorities from today's plan]
**Blockers**: [any blockers noted, or "none"]
```

Keep it to 3 lines. This is for a standup, not a novel.
