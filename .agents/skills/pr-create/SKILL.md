---
name: pr-create
description: Commit the current changes and create a pull request with Jira integration.
argument-hint: "[<ticket-id>] [--draft] [--no-jira]"
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# PR Create

Commit the current changes and create a pull request with optional Jira integration.

## Jira Board Configuration

Read Jira project configuration from `config.yaml: jira.projects[]`. Each project has:
- `key` — project key (e.g., `AI1099`, `SPIN`)
- `name` — display name
- `ticket_pattern` — regex for ticket IDs
- Board-specific defaults for labels, epic search, and transitions

**Board-specific behavior** is defined per-project in `config.yaml`. If the config includes `pr_transitions`, `default_labels`, or `epic_search_jql` for a project, use those. Otherwise fall back to sensible defaults.

## FILE and FOLDER

Used in Phase 2 (read) and Phase 5 (write).

- **FOLDER**: `~/.agent/` (Windows: `%APPDATA%/.agent/` or `%USERPROFILE%/.agent/`), or project root if that directory cannot be created or is not writable.
- **FILE**: `jira-{repo-name}-{board-key}.local.json` in FOLDER. Repo from `git remote get-url origin`. Board key: from the Jira ticket id (e.g. `AI1099` from `AI1099-1234`), or the first project key from config when creating a new ticket. Example: `jira-AI-1099-AI1099.local.json`.

## Workflow

Only proceed to the next phase when the current phase is completed.
When asking questions, always use `AskUserQuestion` tool to ask the user questions.

---

## Phase 1: Confirm readiness

**Goal**: Ensure changes have been reviewed before creating a PR.

**Actions**:

1. Confirm if the user has reviewed the changes using `/review-code`.
   - Use `AskUserQuestion` tool to ask the user.
2. If the user says **no**, ask them to run the review command and **do not proceed**. Stop here.
3. If the user says **yes**, proceed to Phase 2.

---

## Phase 2: Ask for Jira ticket choice and confirm Epic and Labels

**Goal**: Know whether to use an existing Jira ticket or create a new one, and get user confirmation for epic and labels. Use these in Phase 5.

Skip this phase if `--no-jira` flag is set.

**Actions** (read from FILE; board key from ticket id for existing, or first config project key for create new):

1. Ask the user: **provide an existing ticket** (e.g. matching a `ticket_pattern` from config) or **create a new one**.
2. If **existing**:
   - Ask for the ticket id and remember it.
   - `getJiraIssue` to fetch the ticket. If it has an epic and labels, remember them for Phase 5 and proceed to step 4.
   - **If the ticket has no epic**: Read FILE. If it has valid `epics`, use them first (prepend, most recent first), else `searchJiraIssuesUsingJql` with `assignee = currentUser() AND updated >= -30d AND parent is not EMPTY`. Show options, ask which is the parent, remember.
   - **If the ticket has no labels**: Read FILE for `labels`. If present, use as default, else `searchJiraIssuesUsingJql` with `assignee = currentUser() AND updated >= -30d AND labels is not EMPTY`. Show options, ask which to apply, remember. If the user selects none and there are no stored defaults, use board defaults from config for Phase 5.
3. If **create new**:
   - **Determine board**: If multiple Jira projects are configured, ask user which board. If only one, use it.
   - **Epic**: Read FILE (board key from selected board). If it has valid `epics`, use them first (prepend, most recent first), else `searchJiraIssuesUsingJql` for recent epics in that project. Show options, ask which is the parent, remember.
   - **Labels**: Read FILE for `labels`. If present, use as default, else `searchJiraIssuesUsingJql` with `assignee = currentUser() AND updated >= -30d AND labels is not EMPTY`. Show options, ask which to apply, remember. If the user selects none and no stored defaults, use board defaults from config for Phase 5.
   - Ask the user to confirm if the epic and labels are correct.
4. Proceed to Phase 3.

---

## Phase 3: Gather context and prepare branch

**Goal**: Understand the changes and ensure we are not committing directly to the main/develop branch.

**Actions**:

1. Gather context:
   - Current branch: `git branch --show-current`
   - Git status: `git status --short`
   - Recent commits: `git log --oneline -20`
   - Parent branch (reflog): `git reflog show --no-abbrev HEAD`
2. If the current branch is the **base branch** (main or develop):
   - Create a new branch before committing.
   - Branch name:
      - If the code change is part of a plan.md, use `{plan_name}/{task_name}` as the branch name.
      - Otherwise, use `{area}/{summary}` as the branch name. Area is based on changed files. Summary should be under 15 chars.
   - **Never commit directly to the base branch.**
3. Base branch for the PR is the parent branch of the current branch.

---

## Phase 4: Commit and push

**Goal**: Commit all pending changes and push to the remote.

**Actions**:

1. Stage all relevant changes (`git add` — be selective, avoid secrets or large binaries).
2. Write a clear commit message summarizing the changes.
3. Push to the remote with tracking (`git push -u origin <branch>`).

---

## Phase 5: Get or create Jira ticket

**Goal**: Resolve the Jira ticket using the choice from Phase 2. Do not proceed to Phase 6 without a valid ticket (unless `--no-jira`).

Skip this phase if `--no-jira` flag is set.

**Actions**:

Resolve the ticket via **Option A** (existing) or **Option B** (create new), according to Phase 2.

### Saving to FILE (Phase 5)

When persisting transitions, epics, or labels to FILE (see FILE and FOLDER):

- **Contents** (merge into existing): `{"transitions": [...], "epics": [{"epicKey": "PROJ-XXXX", "epicSummary": "Epic Name"}, ...], "labels": ["Label1", "Label2", ...]}`
- Preserve existing `epics`, `labels`, and `transitions` when updating one of them.
- Create the `.agent` directory in FOLDER and FILE if they do not exist.

### Option A: Use an existing ticket

Use the ticket id, epic, and labels from Phase 2.

1. Get details with `getJiraIssue`.
2. **Set status to appropriate state**:
   - Use the project's configured PR transition (from config or FILE).
   - `getTransitionsForJiraIssue` -> find transition -> `transitionJiraIssue`.
   - Some transitions may require fields (assignee, story points) — set those first via `editJiraIssue`.
   - Save the transitions to FILE; preserve `epics` and `labels`.
3. If Phase 2 provided an **epic**: apply via `editJiraIssue`. Update FILE: put that epic at the front of `epics` (dedupe, keep up to 5), preserve `transitions` and `labels`.
4. If Phase 2 provided **labels**: apply via `editJiraIssue`. Update FILE: put those labels at the front of `labels` (dedupe, keep up to 3), preserve `transitions` and `epics`.

### Option B: Create a new ticket

Use the epic and labels confirmed in Phase 2.

1. Create a new ticket in the selected project. Determine the type from commit history (default: `Task`). Use the commit message or change context from Phase 3-4 for summary and description (format: `{Area} / {summary}`).
2. Assign the ticket to the current user.
3. **Set status to appropriate state**:
   - Use the project's configured PR transition.
   - Some transitions require fields first (e.g., assignee, story points) — set via `editJiraIssue` before transitioning.
   - `getTransitionsForJiraIssue` -> find transition -> `transitionJiraIssue`.
   - Save the transitions to FILE; preserve `epics` and `labels`.
4. **Epic** (from Phase 2): Apply via `editJiraIssue`. Update FILE: put that epic at the front of `epics` (dedupe; keep up to 5 total), preserve `transitions` and `labels`.
5. **Labels** (from Phase 2): Apply via `editJiraIssue`. Update FILE: put those labels at the front of `labels` (dedupe, keep up to 3), preserve `transitions` and `epics`.

---

## Phase 6: Draft PR title and summary

**Goal**: Prepare a PR title and summary from the changes.

**Actions**:

1. Draft a PR title using format: `{Area} / {description}`
   - Determine area from the directories containing the most changes.
   - Combine areas if needed: `API, Core / add user profile feature`
2. Draft a PR summary based on the changes in the PR.
3. Use `AskUserQuestion` to confirm: "PR title: '<title>'. Looks good?"

---

## Phase 7: Create PR

**Goal**: Create the PR with `gh` and fill the template.

**Actions**:

1. **Branch**:
   - If on the base branch: a new branch must have been created in Phase 3; create the PR from the feature branch.
   - If on a feature branch: create the PR from the current branch.
   - Base branch: the detected parent branch (main or develop).
2. **Template**: If `.github/pull_request_template.md` exists, fill it and mark checkboxes by change type.
3. Run `gh pr create --title "<title>" --body "<body>"` to create the PR.
   - If `--draft` flag → add `--draft`.

---

## Phase 8: Report

**Goal**: Share the PR link.

**Actions**:

1. Report the PR url in markdown format `[PR title](PR url)` to the user.
2. If a Jira ticket was linked, include the ticket ID and link.
