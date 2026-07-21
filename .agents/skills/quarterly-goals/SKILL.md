---
name: quarterly-goals
description: Track quarterly goals across teams. Set up new goals, add mid-quarter priorities, run weekly goal checks, and assess capacity impact of scope changes.
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Quarterly Goals Tracker

Track progress against quarterly objectives across all teams, ensure weekly work ladders up to these goals, and flag when things are off track.

The user's team structure is defined in `config.yaml` under `teams[]`. Each team maps to a Jira project key and a Confluence space.

## Input

The user may:
- Ask to set up / refresh quarterly goals (typically start of quarter)
- Ask to add a new mid-quarter goal ("we just got a new priority")
- Ask for a weekly goal check ("are we on track?")
- Ask how a specific task connects to quarterly goals

## Process

### Setting Up Quarterly Goals

#### Step 1: Gather Goals from All Teams

For each team in `config.yaml: teams[]`:
1. Search the team's Confluence space for quarterly planning docs
2. Search Jira for epics in the team's project
3. Read relevant pages and epics to understand the goals

#### Step 2: Structure the Goals

Before creating a new goals file, check if `context/active/goals.md` exists from a previous quarter. If so, archive it to `context/archive/YYYY/QN/goals.md`.

Then write to `context/active/goals.md` with sections for: Original Goals (per team), Mid-Quarter Additions, Capacity Budget, Scope Change Log, Monthly Milestones, Weekly Goal Connection, and Unconnected Work Log.

Keep `goals.md` as the automation source of truth. If the goals plan is meant to be reviewed, shared, or presented, also create/update `context/active/goals.html` using `context/standards/html-plan-standard.md` as a companion view.

### Adding a Mid-Quarter Goal

#### Step 1: Understand the New Goal

Ask the user: What is it? Who requested it? What's the deadline? What's the estimated effort?

#### Step 2: Assess Current Capacity

Read `context/active/goals.md` and calculate remaining capacity vs new goal effort.

#### Step 3: Show the Impact on Existing Goals

If the new goal doesn't fit cleanly, present options:
- Reduce scope on existing goals
- Push a goal to next quarter
- Delegate parts of existing goals
- Accept overcommitment (NOT RECOMMENDED)

#### Step 4: Update the Goals File

Add to "Mid-Quarter Additions", update Capacity Budget, add to Scope Change Log.

#### Step 5: Communicate the Change

Draft a message communicating the priority change and what was displaced.

### Weekly Goal Check

#### Step 1: Read Current Goals

Read `context/active/goals.md`.

#### Step 2: Check Jira Progress

For each goal's linked epics, check current ticket status.

#### Step 2b: Detect Untracked New Goals

Search for new epics and Confluence docs that appeared since last check but aren't in the goals file. Flag potential untracked goals.

#### Step 3: Calculate Trajectory

For each goal: progress %, weeks remaining, required pace vs current pace, trajectory verdict.

#### Step 4: Check Work Alignment

Compare this week's planned work against goals. Flag goals getting no attention and time spent on unconnected work.

#### Step 5: Flag Risks

Proactively flag:
- Goals with no activity for 2+ weeks
- Goals where pace needs to double to hit the deadline
- Scope creep without timeline adjustment
- Month-end milestones at risk

## Important Notes

- Not every task needs to map to a quarterly goal. PR reviews, support, mentoring are valuable but don't always connect directly. Track the ratio but don't obsess over 100% alignment.
- If more than 40% of weekly hours are "unconnected," flag the pattern.
- Update goal percentages weekly, not daily.
- When a goal is at risk, always present options — don't just report the problem.
- **Mid-quarter additions are normal, not failures.** The system tracks them to make the math visible.
- If more than 30% of committed hours come from mid-quarter additions, flag this to leadership.
