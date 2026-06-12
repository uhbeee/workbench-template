---
name: estimate
description: Produce realistic time estimates for engineering tasks. Breaks down hidden work, applies calibrated multipliers, and gives three-point estimates. Counteracts chronic underestimation.
metadata:
  workbench.argument-hint: "<task description or Jira ticket ID>"
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Time Estimator

Produce realistic time estimates for engineering tasks, specifically calibrated for someone who chronically underestimates.

## The Core Problem

The user consistently underestimates how long tasks take. This skill exists to counteract that bias systematically. Every estimate produced should feel slightly uncomfortable — that's the right amount.

## Input

The user will describe a task. It might be:
- A Jira ticket ID (fetch it for details)
- A verbal description of work to be done
- A Slack request someone made

## Process

### Step 0: Load Calibration Data

**Before doing anything else**, read `context/calibration.md` to get:
- Calibrated multipliers (if enough samples exist, use these instead of defaults)
- Current pace factor (if the running average is below 1.0, apply it as an additional multiplier)
- Overall estimation ratio trend (is the user getting more accurate or still underestimating?)

If the calibration file has `high` confidence data for a category, use the calibrated multiplier. If `medium`, use the calibrated multiplier but never go below the default. If `low`, use the default.

### Step 1: Understand the Task

If given a Jira ticket, fetch it using `mcp__claude_ai_Atlassian__getJiraIssue`. Get the full picture including comments and linked docs.

If given a description, ask clarifying questions if the scope is ambiguous. Don't estimate vague things — pin down the scope first.

### Step 2: Break It Down

Decompose the task into every concrete subtask. Include the ones people forget:

```
Visible work:
  - [ ] Understand existing code / context gathering: Xh
  - [ ] Design / plan approach: Xh
  - [ ] Implementation: Xh
  - [ ] Write tests: Xh
  - [ ] Manual testing / validation: Xh

Hidden work (people always forget these):
  - [ ] PR creation + description: 0.5h
  - [ ] First round of PR review feedback: 0.5-1 day wait + 1-2h to address
  - [ ] Second round of review (if complex): 0.5 day wait + 1h
  - [ ] Merge conflicts / rebase after review: 0.5h
  - [ ] Deploy and verify in staging: 0.5-1h
  - [ ] Documentation updates (if applicable): 1h
  - [ ] Slack discussions / alignment with team: 1h
  - [ ] Context switching overhead: 0.5h per switch

Coordination work (if applicable):
  - [ ] Sync with other team: Xh
  - [ ] Waiting on dependency: X days (this is elapsed time, not effort)
  - [ ] Cross-repo changes: additional Xh per repo
```

### Step 3: Apply Multipliers

Take the raw subtask sum and apply the appropriate multiplier. **Check calibration.md first** — if calibrated values exist with medium or high confidence, use those instead of the defaults below.

| Condition | Default | Use calibrated if available |
|-----------|---------|----------------------------|
| Familiar code, clear requirements | 1.5x | Yes |
| Familiar code, unclear requirements | 1.75x | Yes |
| Unfamiliar code, clear requirements | 2x | Yes |
| Unfamiliar code, unclear requirements | 2.5x | Yes |
| Involves a system you've never touched | 3x | Yes |

Additionally, check the **pace factor** from calibration.md. If the running average pace factor is below 1.0 (meaning tasks consistently take longer than even the calibrated estimates), apply an additional adjustment:
- Pace factor 0.9: multiply estimate by 1.1
- Pace factor 0.8: multiply estimate by 1.25
- Pace factor 0.7: multiply estimate by 1.4

These are NOT padding — they account for the unknown unknowns that always appear.

### Step 4: Produce the Estimate

Present as a three-point estimate:

```
## Estimate: [Task Description]

### Breakdown
| Subtask | Hours |
|---------|-------|
| Context gathering | X |
| Implementation | X |
| Tests | X |
| PR + review cycles | X |
| Hidden work | X |
| **Raw total** | **X** |

### Adjusted Estimate
- Complexity: [familiar/unfamiliar] code, [clear/unclear] requirements
- Multiplier applied: Xx
- **Best case**: Xh (everything goes perfectly, no surprises)
- **Realistic**: Xh (some surprises, normal review cycles) <- USE THIS ONE
- **Worst case**: Xh (unforeseen complexity, multiple review rounds, blocked by dependencies)

### Calendar Time
- Effort hours: X
- With meetings + other work: X days elapsed
- If started today, realistic completion: [date]
- If other priorities come first, realistic completion: [date]

### What Could Blow Up the Estimate
- [Specific risk 1]: would add X hours
- [Specific risk 2]: would add X hours
```

### Step 5: Give the Communicable Timeline

Draft what to actually tell the person asking:

```
What to say:
  "This will take [realistic estimate] to complete. I can start [when]
   and have it ready for review by [date]. If review goes smoothly,
   it ships by [date]."

If they push back:
  "The [best case] timeline assumes [specific assumptions]. If those
   hold, I could have it by [earlier date], but I'd rather commit to
   [realistic date] and deliver early than promise [earlier date] and miss."
```

## Important Notes

- **Always use the realistic estimate when communicating timelines.** Never give the best case as the timeline.
- The multiplier is not negotiable. It's based on decades of software estimation research.
- Calendar time != effort hours. Assume 5-6h of productive work per day.
- If the user says "but it's simple, it should only take X hours" — that's the bias talking. Ask them to walk through the subtasks.
- **After producing an estimate**, always note the category used so the calibration file can be updated when actuals are known.
