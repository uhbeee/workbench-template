---
name: weekly-retro
description: End-of-week retrospective. Compares planned vs actual, updates calibration data, and surfaces estimation patterns. Run Friday afternoons.
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Weekly Retrospective

Review what actually happened this week versus what was planned, update calibration data, and surface patterns.

## When to Run

End of the work week (typically Friday). Run this before the next weekly planning session so the data feeds forward.

## Process

### Step 1: Gather the Week's Data

1. Read `context/active/weekly.md` to get this week's committed items and estimates
2. Find this week's daily plans:
   - Read `context/active/daily.md` (today)
   - Check `context/archive/YYYY/MM/daily/` for the other days of this week
3. For each daily plan found, extract:
   - Completed items
   - Actual hours (from End of Day section)
   - Interrupts logged
   - Items rolled forward

### Step 2: Compare Planned vs Actual

Build a comparison table for every committed item in the weekly plan:

```
| Item | Estimated | Actual | Ratio | Status |
|------|-----------|--------|-------|--------|
| Feature X implementation | 8h | 12h | 1.5x | Completed |
| PR review for Y | 2h | 1h | 0.5x | Completed |
| Bug fix Z | 4h | — | — | Rolled forward |
```

Calculate:
- Total planned hours vs total actual hours
- Average estimation ratio (actual/estimated)
- Completion rate (items completed / items committed)
- Interrupt hours absorbed

### Step 3: Update Calibration Data

Read `context/calibration.md`. For each completed item that has both an estimate and actual:

1. Identify the estimation category (familiar/unfamiliar, clear/unclear) — check the weekly plan or estimate notes for this
2. Add a new data point:
   ```
   - YYYY-MM-DD | [task description] | category: [X] | estimated: Xh | actual: Xh | ratio: X.Xx
   ```
3. Recalculate the running averages for each category if there are enough samples
4. Update the pace factor: `pace_factor = average(this_week_ratio, last_4_weeks_pace_factor)`
5. Update confidence levels:
   - 0-4 samples: low
   - 5-14 samples: medium
   - 15+ samples: high

Save the updated `context/calibration.md`.

### Step 4: Identify Patterns

Look across the week for recurring themes:
- **Chronic underestimates**: Which types of tasks always take longer?
- **Interrupt sources**: Who/what caused most interrupts? Are they predictable?
- **Time sinks**: Where did time disappear that wasn't accounted for?
- **Bright spots**: What was accurately estimated or completed ahead of schedule?
- **Carried forward**: Items that rolled forward multiple days — are they blocked or just low priority?

### Step 5: Produce the Retrospective

```
## Weekly Retrospective — Week of YYYY-MM-DD

### Summary
- Committed: X items (Yh estimated)
- Completed: X items (Yh actual)
- Completion rate: X%
- Estimation accuracy: X.Xx average ratio (target: 1.0)
- Interrupts absorbed: Xh across Y interrupts

### Estimation Accuracy
| Category | Samples | Avg Ratio | Confidence | Trend |
|----------|---------|-----------|------------|-------|
| Familiar/Clear | N | X.Xx | low/med/high | improving/stable/degrading |
| ... | | | | |

### Patterns
- [pattern 1 — e.g., "PR review cycles consistently take 2x estimated"]
- [pattern 2 — e.g., "Monday interrupts from #channel average 1.5h"]

### Recommendations for Next Week
- [actionable recommendation based on data]
- [e.g., "Add 1h buffer for each PR that touches shared code"]

### Pace Factor
- This week: X.Xx
- Running average: X.Xx
- Trend: [improving/stable/declining]
```

## Important Notes

- This agent feeds the calibration system. Accurate data here means better estimates everywhere.
- Don't judge — just measure. A "bad" week with honest data is more valuable than a "good" week with fudged numbers.
- If actual hours aren't recorded in daily plans, note the gap and encourage better tracking next week.
- The retrospective should take 5-10 minutes to review, not 30. Keep it focused.
