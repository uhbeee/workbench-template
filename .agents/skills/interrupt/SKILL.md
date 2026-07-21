---
name: interrupt
description: Handle urgent interrupt requests. Sizes the impact, shows tradeoffs against current plan, and helps decide whether to take it on, delegate, or push back.
metadata:
  workbench.argument-hint: "<interrupt description>"
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Interrupt Handler

Someone just said "this is urgent, it needs to happen now." This skill makes the tradeoffs visible so a good decision gets made fast.

## Input

The user will describe:
- What the new urgent task is
- Who requested it (manager, team lead, stakeholder)
- Any deadline mentioned

## Process

### Step 1: Size the Interrupt

Break the new task into concrete subtasks and estimate each one. Apply the estimation rules:
- Get the gut feel for each subtask
- Apply the 1.5x multiplier (2x if it involves unfamiliar code, coordination with others, or unknowns)
- Add PR review cycle time (0.5 day minimum)
- Add context-switching overhead (0.5h for getting into it, 0.5h for getting back to what you were doing)

Present:
```
New task: [description]
Requested by: [who]
Estimated effort: X-Y hours (best case / realistic)
Subtasks:
  - Subtask 1: Xh
  - Subtask 2: Yh
  - PR review + iteration: Zh
  - Context switch overhead: 1h
```

### Step 2: Show Current State

Read today's daily plan (`context/active/daily.md`) and the weekly plan (`context/active/weekly.md`).

Present:
```
Today's remaining work:
  - [ ] Item A (est: Xh) — WHY: reason
  - [ ] Item B (est: Yh) — WHY: reason

This week's capacity:
  - Committed: Xh of Yh available
  - Remaining capacity: Zh
  - Already at risk: [any items close to deadline]
```

### Step 3: Show the Impact

Make the tradeoffs explicit:

```
Option 1: Take it on now
  -> Item A slips to [when]
  -> Item B slips to [when]
  -> [Person waiting on A] will be affected
  -> Weekly capacity goes from X% to Y% utilized

Option 2: Take it on, but defer lower-priority work
  -> Complete by [when]
  -> Defer [specific items] to next week
  -> Impact: [who is affected by the deferral]

Option 3: Delegate it
  -> This task [does/doesn't] require principal-level expertise
  -> Could be handled by: [suggestion based on complexity]
  -> You'd need to: [brief handoff effort estimate]
  -> Net time cost to you: Xh (handoff) vs Yh (doing it yourself)

Option 4: Push back with a counter-timeline
  -> "I can start this [when] and have it done by [when]"
  -> Current work stays on track
  -> Risk: [whoever asked] may not accept the delay
```

### Step 4: Help Respond

Based on the decision:

**If taking it on:**
- Update today's daily plan — move the new task to #1, shift everything else
- Update the weekly plan with new capacity numbers
- Flag anything that now needs to be communicated to stakeholders

**If delegating:**
- Draft a handoff message with context the other engineer needs
- Offer to send it via Slack

**If pushing back:**
- Draft a response to the requester with:
  - Acknowledgment that it's important
  - Your current commitments and why they matter
  - A realistic counter-timeline
  - What would need to change for you to do it sooner

## Important Notes

- Never frame this as "you're too busy." Frame it as tradeoffs: "here's what taking this on costs."
- The goal is to make the requester's decision informed, not to say no.
- If the requester is a VP or above, note that but don't automatically capitulate — still show the tradeoffs.
- If this is a genuine emergency (production down, data loss, security issue), skip the analysis and just flag what gets deferred.
- Speed matters here. The whole analysis should take under 60 seconds to produce.
