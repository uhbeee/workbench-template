---
name: weekly-plan
description: Create and maintain a realistic weekly capacity plan. Tracks actuals vs estimates, checks if new tasks fit, and manages the weekly cycle. Run Monday mornings.
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Weekly Plan

Create and maintain a realistic capacity plan for the week, track actuals vs estimates, and answer "can I fit this in?"

The user's Jira projects are defined in `config.yaml` under `jira.projects`. Slack channels are defined in `config.yaml` under `slack.channels`. Capacity defaults and estimation multipliers are in `config.yaml` under `capacity` and `estimation.multipliers`.

## Input

The user may:
- Ask to create a new weekly plan (typically Monday morning)
- Ask "can I fit X in this week?"
- Ask to review/update the current week's plan

## Process

### Creating a New Weekly Plan

#### Step 1: Gather Commitments

Check all sources for this week's work:

1. **Jira**: Search for tickets assigned to the user in all configured Jira projects (from `config.yaml: jira.projects`) that are in-progress or planned for this sprint using `mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql`.
2. **Carried forward**: Read last week's plan from `context/active/weekly.md` (if it's from a previous week) or `context/archive/` for anything that rolled over.
3. **Today's daily plan**: Check `context/active/daily.md` for items already identified.
4. **Slack**: Quick scan of engineering and operations channels (from `config.yaml: slack.channels`) for anything committed to but not yet in Jira.

#### Step 2: Estimate Each Item

For every task, create an estimate using these rules:

1. Break into subtasks (design, implement, test, PR, review cycles)
2. Get a gut-feel hour count for each subtask
3. **Apply the multiplier** from `config.yaml: estimation.multipliers`:
   - Familiar code, clear requirements: `familiar_clear` multiplier
   - Unfamiliar code OR unclear requirements: `unfamiliar_clear` or `familiar_unclear` multiplier
   - Unfamiliar code AND unclear requirements: `unfamiliar_unclear` multiplier
   - Cross-team coordination involved: add 1-2h for communication overhead
4. Add PR review cycle time: 0.5 day (4h) for standard PRs, 1 day for large/complex PRs
5. Round up, never down

Present each estimate as a range: `best case / realistic / worst case`

#### Step 2b: Read Calendar Data

Check `context/active/calendar.md` for this week's actual meeting schedule.
- If the file exists, use the real meeting hours per day.
- If the file doesn't exist or is outdated, suggest running `/calendar-sync` first to get accurate data.
- Fall back to the default meeting overhead from `config.yaml: capacity.meeting_overhead` only if calendar sync isn't available.

#### Step 2c: Read Calibration Data

Check `context/calibration.md` for:
- Current pace factor (apply to estimates if below 1.0)
- Calibrated multipliers (use in Step 2 estimates)
- Previous weeks' estimation accuracy (inform capacity buffer)

#### Step 2d: Check Quarterly Goals

Read `context/active/goals.md` for active quarterly goals.
- Which goals have deliverables due this month?
- Are any goals behind pace and need catch-up hours this week?
- Were any new mid-quarter goals added recently?

Flag any weekly plan that doesn't allocate time to an at-risk quarterly goal.

#### Step 3: Calculate Capacity

```
Weekly capacity model:
  Total hours in week:          40h
  Meetings (from calendar):    -Xh  <- use real data from calendar-sync
  Slack/comms overhead:        -Xh  (from config.yaml: capacity.slack_overhead)
  Context switching:           -Xh  (from config.yaml: capacity.context_switching)
  Unexpected interrupts:       -Xh  (from config.yaml: capacity.interrupt_buffer)
  Pace factor adjustment:      -Xh  (if pace factor < 1.0)
  ------
  Productive hours:             Xh
```

Use the real meeting hours from `context/active/calendar.md` when available. If calendar data shows a heavy meeting week (15h+), call it out explicitly — productive capacity may be as low as 14-16h.

The interrupt buffer is non-negotiable — something always comes up.

#### Step 4: Create the Weekly Plan File

Before creating the new plan:
1. Check if `context/active/weekly.md` exists and is from a previous week.
2. If so, archive it to `context/archive/YYYY/MM/weekly/YYYY-WNN.md` (creating directories as needed).
3. Also archive `context/active/calendar.md` to `context/archive/YYYY/MM/calendar/YYYY-WNN.md` if it's from last week.

Then write to `context/active/weekly.md` using the format defined in CLAUDE.md. Keep this Markdown file as the automation source of truth.

If the weekly plan is meant to be reviewed or shared, also create/update `context/active/weekly.html` using `context/standards/html-plan-standard.md` as a companion view. Do not replace `weekly.md`.

### Answering "Can I Fit This In?"

#### Step 1: Read Current Weekly Plan

Read `context/active/weekly.md` for current capacity state.

#### Step 2: Estimate the New Task

Apply the full estimation process (subtasks, multiplier, PR cycles).

#### Step 3: Give a Clear Answer

```
New task: [description]
Estimated effort: X-Y hours

Current state:
  Committed: Xh / Yh available
  Remaining capacity: Zh (includes interrupt buffer)

Verdict:
  Yes, fits comfortably — Z hours of margin remaining
  Tight — fits only if nothing else comes up (eats into interrupt buffer)
  Doesn't fit — would need to defer [specific items] to make room

If you take this on:
  -> [Item X] moves to next week
  -> Realistic completion: [day]
  -> You should tell [person] about the delay on [Item X]
```

Always give a concrete "you should tell [person]" if something slips. Unspoken delays are worse than communicated ones.

### Updating the Weekly Plan

When tasks complete or actuals become known:
- Update the actual hours column
- Calculate the estimation ratio (actual/estimated)
- Update remaining capacity
- If a pattern emerges (e.g., consistently 1.8x the estimate), flag it

## Important Notes

- The interrupt buffer is sacred. Do not schedule into it. It exists because interrupts are guaranteed.
- When capacity is tight, be explicit: "You are at 95% utilization this week. Any interrupt will cause something to slip. Consider deferring [lowest priority item] proactively."
- Track estimation accuracy over weeks. If actuals are consistently 2x estimates, adjust the default multiplier up.
- "Stretch goals" are not commitments. Never let them creep into committed work without a capacity check.
- Friday afternoon: always suggest running the end-of-week review to update the accuracy tracker and calibration data.
- The calendar data makes capacity real, not theoretical. A week with 15h of meetings and a week with 6h of meetings have radically different productive capacity. Never plan them the same way.
