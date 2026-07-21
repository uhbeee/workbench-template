---
name: what-next
description: Recommend the next highest-impact task based on remaining capacity, priority order, and pending DMs. Use when deciding what to work on next.
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Priority Recommender

Recommend the next highest-impact task based on remaining capacity and priorities.

## Process

1. Read `context/active/daily.md`
2. If the file doesn't exist, suggest running morning-triage
3. Identify:
   - Incomplete items from `## Top Priorities` (in order)
   - Incomplete items from `## DMs and @Mentions`
   - Incomplete items from `## Carried Forward`
   - Remaining capacity from `## Capacity Today`
4. Filter to items that fit in remaining capacity
5. Rank by:
   - DMs and @mentions first (people are waiting)
   - Items with deadlines today
   - Top priorities in listed order
   - Carried forward items (already delayed once)

## Output

```
**Next up**: [recommended item] [est: Xh]
**Why**: [reason — e.g., "@person is waiting", "deadline today", "highest priority remaining"]
**Remaining capacity**: Xh (fits Y more items after this)
```

If no capacity remains, say so. If all items are done, congratulate and suggest checking Slack or picking up stretch goals from the weekly plan.
