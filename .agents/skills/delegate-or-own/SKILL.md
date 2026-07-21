---
name: delegate-or-own
description: Decide whether to own a task or delegate it. Assesses principal-level requirement, complexity, and growth opportunity. Generates handoff briefs for delegation.
metadata:
  workbench.argument-hint: "<task description>"
---

# Delegate or Own

Help decide whether a task should be done personally or handed to another engineer, and make that handoff smooth if delegating.

## Input

The user will describe a task and optionally mention:
- Who requested it
- Any deadline
- Whether they have someone in mind to delegate to

## Process

### Step 1: Assess the Task

Evaluate across these dimensions:

```
Principal-level requirement?
  - Deep architectural knowledge?     [yes/no]
  - Cross-system understanding?       [yes/no]
  - Significant design decision?      [yes/no]
  - Customer/stakeholder visible?     [yes/no]
  - Wrong approach = significant debt? [yes/no]

Complexity:
  - Lines of code: [small/medium/large]
  - Systems touched: [1/2-3/many]
  - Estimated effort: [hours]

Growth opportunity?
  - Good learning task for a mid/senior engineer?
  - Scope well-defined enough for someone else?
  - Existing pattern they can follow?
```

### Step 2: Make the Recommendation

```
Delegation Score:
  Delegate if: 0-1 "yes" on principal-level questions, small-medium complexity
  Delegate with oversight if: 2 "yes", medium complexity
  Own it if: 3+ "yes", high complexity or cross-system impact
```

Present: recommendation, reason, time comparison (handoff effort vs doing it yourself).

### Step 3: If Delegating — Prepare the Handoff

Create a structured handoff brief with: what needs to be done, context (Jira/design docs), approach suggestion, key files/entry points, gotchas, definition of done, and topics to ask about.

If the handoff brief is saved or shared as a standalone artifact, read `context/standards/html-plan-standard.md` and create `handoff-brief.html` as the primary artifact. Use Slack/email Markdown only as a paste-format companion.

Offer to send via Slack after approval.

### Step 4: If Owning — Update Plans

Get a proper estimate, check weekly capacity, update daily and weekly plans, flag if this pushes other things out.

## Important Notes

- A principal engineer who does everything themselves is a bottleneck, not a force multiplier. Delegation is leverage.
- But delegating something that requires your judgment just to save time is a false economy.
- The handoff brief should be thorough enough that the person doesn't need to come back with basic questions.
- "Delegate with oversight" = you write the approach, they implement, you review.
- If a task is delegatable but there's no one available, that's still useful information.
