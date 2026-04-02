---
name: plan-implement
description: Implement the next pending task in the plan.
argument-hint: [plan-or-pr-breakdown-file]
---

## Context Management

If at any point during implementation the conversation is getting long (e.g., many files edited, extensive debugging, multiple review rounds), proactively run `/handoff <plan-folder-path>` to save progress. This writes a `HANDOFF.md` to the plan folder so a fresh session can continue exactly where this one left off. Do this **before** context quality degrades - don't wait until the last moment. Signs to watch for:
- You've completed multiple phases and are deep into Phase 3 (implementation)
- Extensive back-and-forth debugging or review cycles
- You've read/edited many files and context is dense

---

## Workflow

## Phase 1: Initialize

**Goal**: Initialize the implementation

**Actions**:

1. Create a todo list with all phases
2. Check for a `HANDOFF.md` in the plan folder. If it exists, read it first to understand prior session context (what was done, what worked, what didn't, and where to pick up).
3. Review the plan
   - If the user provides a plan file, review the plan and the related `pr-breakdown.md` file.
   - If the user provides a pr-breakdown file, review the pr-breakdown and the related `plan.md` file.

File: $1

---

## Phase 2: Confirm next pending task

**Goal**: Confirm the next pending task with the user

**Actions**:

- For Cursor, use `AskQuestion` tool to ask the user questions.
- For Claude Code, use `AskUserQuestion` tool to ask the user questions.

1. Review the plan or pr-breakdown file to confirm the next pending task.
2. Ask the user to confirm the next pending task.
3. Ask the user if they want to create a new branch for this task. If  yes, create a new branch with the name `{plan-name}/{task-name}` base on the current branch `{branch-name}`.

Do not proceed to the next phase until the user confirms the next pending task.
Ask questions sequentially, waiting for confirmation after each one.

---

## Phase 3: Implement the next pending task

**Goal**: Implement the next pending task

**Actions**:

1. Follow the step in the PR and implement the next pending task.

---

## Phase 4: User review

**Goal**: Ask user to review the implementation

**Actions**:

- For Cursor, use `AskQuestion` tool to ask the user questions.
- For Claude Code, use `AskUserQuestion` tool to ask the user questions.

1. Ask the user to review the implementation.
2. Make adjustments based on the user's feedback.
3. Get explicit confirmation from the user before proceeding to the next phase.

---
## Phase 5: Commit the changes

**Goal**: Commit the changes

**Actions**:

Commit the changes following the commit skill.


---

## Phase 6: Sync the plan

**Goal**: Sync the plan with the latest changes

**Actions**:

Once you finish the task, ask the user to run `/plan-sync` command to update the plan with the latest changes.

---

## Phase 7: Create PR

**Goal**: Create a PR for the changes

**Actions**:

1. Ask the user to run `pr-create` skill to create a PR for the changes.
2. If there are more PRs to implement from the breakdown, run `/handoff <plan-folder-path>` to save session context before the user starts a fresh conversation for the next PR.
3. After the PR is created, ask the user to start a new conversation and implement the next task, so the context window is reset.
