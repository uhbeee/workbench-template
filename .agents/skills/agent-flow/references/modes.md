# Agent Flow Mode Reference

Detailed instructions and packet templates for each mode. Read only the section for the selected mode.

Human-readable packets, state, prompts, validation artifacts, and PR writeups are HTML-native. When this reference shows a Markdown-looking section outline for an `.html` artifact, use it as the content structure inside the HTML page. Do not create `.md` companions for `agent-flow` outputs. Read legacy Markdown artifacts only as fallback input when the matching `.html` artifact is missing, then write the next version as `.html`.

## Full Lifecycle Mode

Goal: make `agent-flow` own the whole gated workflow from initial context to reviewed implementation and PR draft, while implementation and review run in visible interactive terminals.

Use this mode when the user asks for the full workflow, wants the Helix-style plan/review/implement/review loop, or expects `agent-flow` to drive the work instead of stopping at a packet.

Internal helpers:

- Use Forge-style planning interviews when no adequate plan exists.
- Use Helix-style phase implementation after the plan-review gate is accepted.
- Use visible Claude/Codex terminal sessions for independent plan and implementation review.
- Enforce both mandatory review lenses during plan review, implementation review, and PR review: content/intent from Jira, plan, chat, PR, acceptance criteria, and validation evidence; engineering invariants from `references/engineering-invariants.md` and any repo-specific invariant docs.
- Use ship-style behavior for PR/Jira drafts or explicitly approved external writes. Jira drafting is the default unless the user opted out.
- Do not use the Workbench `implement` skill for this lifecycle.
- Do not launch headless/background agents for plan review, implementation, implementation review, or PR review.

Steps:

1. Resolve or create the work item.
   - Read `anchors.html` if present.
   - Create stable `context/work-items/<slug>/` if missing.
   - Add Jira, plan, chat, branch, and PR anchors as they appear.
2. Capture context.
   - If starting from chat, run `capture` behavior first.
   - If starting from Jira or natural language, run `context` behavior.
   - Write or update `context-packet.html`.
3. Plan.
   - If a plan already exists, link it and summarize it into the work item.
   - If no plan exists, run plan-mode behavior inside this lifecycle.
   - Interview the user before finalizing the plan. Write `planning-interview.html` with the user's goal, success behavior, scope, non-goals, service boundaries, risks, rollout concerns, and validation bar.
   - Use the environment's user-question tool for the interview: Claude Code `AskUserQuestion`; Codex `request_user_input` when available; otherwise ask in chat and wait.
   - Read `references/validation-practices.md`. Have the agent propose validation options from repo-native signals, API/runtime paths, Docker/container feasibility, happy-path proof, edge cases, and failure cases; then have the user confirm the validation plan or explicitly delegate that choice.
   - Write or link `plan.html` as the primary plan artifact.
   - Write or update `validation-plan.html` from the user-confirmed validation section of the planning interview.
   - If a legacy `plan.md` exists and no `plan.html` exists, read it as input and write the durable plan as `plan.html`.
4. Prepare the visible pipeline.
   - Write `pipeline.html` if missing.
   - If visible terminal roles are not already explicit, ask the role-assignment question before writing prompts: "Which session is implementer, and which session is reviewer?" Offer concrete answer examples: `Claude implements, Codex reviews` or `Codex implements, Claude reviews`.
   - Write `review-handoff.html` if missing. It must name the implementer terminal, reviewer terminal, current slice, target repo/branch, exact findings output path, exact implementer read path, and current review status.
   - Verify `validation-plan.html` exists and names the behavior to prove, repo-native validation commands, runtime/integration proof, manual checks, cross-repo contract checks, and known gaps.
   - Write `pr-breakdown.html` if missing. Default to small human-readable PR slices: one responsibility per PR, target under 200 meaningful lines, maximum 300 unless approved, explicit dependencies, independent build/test/deploy safety, named validation, stop rules, and reviewer focus.
   - Model `pr-breakdown.html` on `https://thariqs.github.io/html-effectiveness/16-implementation-plan.html`: summary strip, milestone/PR timeline, dependency graph, data/service flow, risky code/contracts, risk table, open questions, validation, and reviewer focus.
   - Include a visible `PR Breakdown And Worktree Contract` section in `pr-breakdown.html` with the small-PR default, dependency rules, branch/worktree matrix, bypass decision, and stop conditions.
   - Adapt `assets/pr-breakdown-worktree-contract.html` when a starter HTML shape helps.
   - Include branch/worktree guidance for every slice when there is more than one PR: repo base path, branch name, base branch, optional worktree path, whether it can run in parallel, what prior PR it depends on, and the exact `cd <repo>.git && wt-feature <branch> <base>` command or script fallback.
   - If the user explicitly approved bypassing detailed PR slicing, write a coarse implementation breakdown instead of tiny PR rows, but record the bypass reason, residual review risk, validation implications, and fallback split.
   - Write `worktree-plan.html` only when the work is actually split across branches/worktrees or another engineer needs copy-paste setup commands.
   - Write `watch-prompts.html` with the exact commands/prompts for the implementer terminal and reviewer terminal. The reviewer prompt must include the absolute findings path to write. The implementer prompt must include the findings path to read before advancing.
   - Write `gates.html` with approvals, validation requirements, and stop conditions.
5. Start or resume the visible terminal pair.
   - The user opens one Claude Code terminal and one Codex terminal.
   - Both terminals run this same skill in `watch` mode against the same work item.
   - Whichever terminal created the plan or is explicitly marked implementer owns implementation and apply-review stages.
   - The other terminal owns review stages.
6. Let `watch` mode advance the state machine:
   - planning interview,
   - plan review,
   - apply plan review,
   - implement plan phase-by-phase,
   - validate implementation,
   - review implementation,
   - apply implementation review,
   - validate accepted fixes,
   - manual verification pause,
   - PR draft/create gate,
   - PR review,
   - apply PR review,
   - final validation,
   - done.
7. Final packet.
   - Create final `reviewer-packet.html`.
   - Include repos to inspect, files to read, service map, validation plan, validation evidence, known risks, and reviewer-agent prompt.
8. PR and publish gate.
   - Draft `pr-draft.html` with title, body, linked Jira, validation, and Agent Review Packet summary.
   - Draft or refresh `jira-draft.html` by default unless `anchors.html` records `Jira: opted out by user`.
   - Ask for explicit approval before creating a PR, pushing, posting Jira comments, updating PR body, or publishing packet summaries.
   - Do not mark the PR gate passed unless `validation-evidence.html` is `passed`, or a user-approved exception is recorded with the reason and residual risk.
   - If approved, perform the requested external write and record it in `activity.html`.

Use this section structure inside `lifecycle.html`:

```text
# Lifecycle: <slug>

## Current Stage
## Anchors
## Gate Status
| Gate | Status | Evidence | Notes |
|---|---|---|---|
| Context captured | pending|passed|blocked | | |
| Planning interview complete | pending|passed|blocked | | |
| Plan created | pending|passed|blocked | | |
| Plan reviewed | pending|passed|blocked | | |
| PR breakdown selected | pending|passed|blocked | | |
| Validation confirmed by user | pending|passed|blocked | | |
| Implementation complete | pending|passed|blocked | | |
| Implementation validation | pending|passed|failed|blocked|unverified | | |
| Implementation reviewed | pending|passed|blocked | | |
| Review fixes validation | pending|passed|failed|blocked|unverified | | |
| Validation complete | pending|passed|blocked | | |
| Engineering invariants reviewed | pending|passed|blocked | | |
| Reviewer packet ready | pending|passed|blocked | | |
| PR drafted | pending|passed|blocked | | |

## Review Cycles
## Visible Terminal Setup
## Validation Evidence
## Open Decisions
## Next Action
```

Use this section structure inside `gates.html`:

```text
# Gates: <slug>

## Approval Required
- Create Jira:
- Modify target repo:
- Push branch:
- Create PR:
- Update Jira/PR:
- Bypass small PR breakdown:

## Loop Limits
- Plan review cycles: one reviewer pass, then implementer applies findings.
- Implementation review cycles: one reviewer pass, then implementer applies findings.
- PR review cycles: one reviewer pass, then implementer applies findings.

## Required Review Criteria
- Content/intent from Jira when present, otherwise plan, chat capture, PR body, branch behavior, acceptance criteria, user/product workflow, and validation evidence.
- Engineering invariants from `references/engineering-invariants.md`.
- Repo-specific invariant docs from `context/agent-flow/invariants.html`, legacy `context/agent-flow/invariants.md`, target repo `knowledge-base/invariants/*.md`, target repo `docs/invariants/*.md`, `AGENTS.md`, or `WORKFLOW.md` when present.
- Cross-repo/service contracts.
- Security, privacy, auth, tenancy, performance, scalability planning, exception handling, tests, documentation, observability, alerting, dashboards, maintainability, and readability.

## Required Cross-Agent Handoff
- `review-handoff.html` names the active roles, current slice, target repo/branch, expected findings path, and review status.
- Reviewer writes the relevant findings artifact even when there are no issues.
- Implementer reads the relevant findings artifact before starting the next PR slice, drafting a PR, or claiming review is complete.
- If reviewer output is expected but missing, implementer stops at the review gate unless the user explicitly approves proceeding without it.

## Required Validation Gates
- Validation plan is created from the planning interview before implementation starts.
- User confirms the validation bar, or explicitly delegates validation selection to the agent with assumptions recorded.
- Implementation validation evidence exists before implementation review starts.
- Accepted review fixes rerun targeted validation before manual verification or PR draft.
- Final PR handoff includes validation evidence or an explicit user-approved exception.

## Required PR Breakdown Gates
- `pr-breakdown.html` exists before implementation starts for any non-trivial code change.
- Default is small, human-readable PR slices with one responsibility each.
- Each slice is independently reviewable, buildable, testable, and deployable.
- Dependencies, base branches, and branch/worktree suggestions are recorded.
- Independent slices are marked parallelizable; dependent slices are explicitly sequential.
- Any coarse/single-PR bypass is user-approved and records reason, residual risk, validation implications, and fallback split.

## Stop Conditions
- Reviewer reports blocker requiring product decision.
- Required repo/context is missing.
- Validation cannot be run.
- Validation fails and the failure is relevant to the change.
- Validation evidence is missing before reviewer packet, PR draft, or publish mode.
- One reviewer pass completed and the implementer needs user approval for an extra pass or scope expansion.
```

Never run an unbounded autonomous loop. The default is Helix-style: one review feedback loop per stage. Additional loops require explicit user instruction.

Use this section structure inside `review-handoff.html`:

```text
# Review Handoff: <slug>

## Role Assignment
- User answer:
- Implementer session:
- Reviewer session:
- Assignment confirmed at:

## Current Review Slot
- Stage: plan-review | implementation-review | pr-review | external-review
- PR slice:
- Target repo:
- Target branch:
- Implementer:
- Reviewer:
- Status: not-started | review-pending | review-complete | blocked | proceed-without-review-approved

## Shared Files
| Purpose | Path | Required |
|---|---|---|
| Pipeline | <work-item>/pipeline.html | yes |
| PR breakdown | <work-item>/pr-breakdown.html | yes |
| Validation evidence | <work-item>/validation-evidence.html | yes |
| Findings output | <work-item>/review-implementation-findings.html | yes |

## Reviewer Instructions
Write findings to the exact output path above. Write a no-findings artifact if no issues are found.

## Implementer Instructions
Read this file and the findings output before starting the next PR slice or PR draft.

## Last Updated
- Time:
- Actor:
- Notes:
```

## Watch Mode

Goal: advance the visible two-terminal pipeline using only filesystem handoffs.

This is how the workflow is hands-free without being headless. The agents run in normal interactive terminals, so the user can see state transitions, progress summaries, findings, test output, blockers, and closeout. The user cannot and should not expect private chain-of-thought, but the visible reasoning artifacts live in `pipeline.html`, findings files, `implementation.html`, `summary.html`, and terminal output.

Core mechanics:

- All state lives in the work item folder: `pipeline.html`, `review-handoff.html`, findings files, `implementation.html`, and per-role lockfiles.
- Every tick re-reads disk and derives the next action. No in-memory state is required to resume.
- Agents never assume they can see another visible terminal's comments. They only treat comments as actionable after they are written to the shared findings file or pasted by the user and captured there.
- The watcher prints one short transition paragraph before running a stage.
- If waiting on the other terminal, it prints one concise idle line and waits.
- Esc/interruption is safe. Re-run `agent-flow <work-item> watch` to resume from disk.
- A blocked row stops the chain. The user fixes the blocker and re-runs watch.
- No daemon, IPC socket, background job, or headless agent process is required.

State machine:

```text
context -> planning-interview -> plan -> review-plan -> apply-review-plan -> implement-plan -> validate-implementation -> review-implementation -> apply-review-implementation -> validate-review-fixes -> paused-for-manual-verification -> create-pr-draft -> review-pr -> apply-review-pr -> final-validation -> done
```

Role ownership:

| Latest row | Implementer terminal | Reviewer terminal |
|---|---|---|
| `context` passed | run `planning-interview` | wait |
| `planning-interview` passed | run `plan` | wait |
| `plan` passed | wait | run `review-plan` |
| `review-plan` passed | run `apply-review-plan` | wait |
| `apply-review-plan` passed | run `implement-plan` | wait |
| `implement-plan` passed | run `validate-implementation` | wait |
| `validate-implementation` passed | wait | run `review-implementation` |
| `review-implementation` passed | run `apply-review-implementation` | wait |
| `apply-review-implementation` passed | run `validate-review-fixes` | wait |
| `validate-review-fixes` passed | write manual verification pause | wait |
| `paused-for-manual-verification` | after user approval, draft/create PR | wait |
| `create-pr-draft` or approved PR created | wait | run `review-pr` |
| `review-pr` passed | run `apply-review-pr` | wait |
| `apply-review-pr` passed | run `final-validation` | wait |
| `final-validation` passed | write `done` | wait |
| `blocked` | stop with blocker and resume instructions | stop with blocker and resume instructions |

Implementation stage contract:

1. Read `context-packet.html`, `planning-interview.html`, `plan.html` when present, legacy `plan.md` only when no HTML plan exists, `validation-plan.html`, `pr-breakdown.html` when present, legacy `pr-breakdown.md` only when no HTML breakdown exists, repo guidance, `references/validation-practices.md`, and relevant service graph entries.
2. Confirm `validation-plan.html` came from the planning interview or an explicit user delegation before changing code. If it is missing, stop and return to plan mode.
3. Scaffold or resume `implementation.html`.
4. Select exactly one pending PR slice from `pr-breakdown.html` unless the breakdown explicitly records a user-approved coarse/single-PR bypass.
5. Confirm the current branch/worktree matches the selected slice's branch/worktree guidance. If not, use the `worktree-feature-create` skill or create the branch/worktree from the repo base directory with `wt-feature`; if that is not safe, stop with the exact base-repo command.
6. Implement slices from `pr-breakdown.html` in dependency order. Parallelizable slices may run in separate visible terminals/worktrees; dependent slices wait for their base PR/branch.
7. Before each slice, record a phase baseline.
8. Touch only files in that slice scope unless asking to expand scope.
9. Run the targeted validation named in `validation-plan.html` for the selected slice. Prefer focused proof over broad suites unless broad suites are required by repo policy or risk.
10. Write `validation-evidence.html` with command, working directory, timestamp, exit status, scope, and result summary.
11. Update `implementation.html` after implementation, validation, review, fixes, and exit criteria.
12. After each completed slice, update `review-handoff.html` with the reviewer output path and set status to `review pending` unless this slice has an explicit user-approved no-review exception.
13. Before starting the next slice, read `review-handoff.html` and the relevant findings artifact. If review is pending or missing, wait or ask the user whether to proceed without reviewer output.
14. Write `summary.html` and `manual-verification.html` after implementation validation is complete.
15. Do not commit automatically.

Validation stage contract:

1. Read `validation-plan.html`, `implementation.html`, changed files, repo docs/config, and `references/validation-practices.md`.
2. Run the required targeted commands unless unsafe or unavailable.
3. Prefer explicit API/tool/runtime calls to get the data needed to prove preconditions and postconditions.
4. If runtime dependencies matter, spin up Docker Compose or Testcontainers-style local dependencies when feasible and record health checks, seed data, logs, and teardown.
5. Cover the planned happy path, edge cases, and negative/failure scenarios.
6. If UI behavior matters, follow the browser validation tool order from `references/validation-practices.md`: Codex browser-use/Browser skill, Claude-in-Chrome/Chrome MCP, Playwright MCP, Playwright CLI, then explicit user handoff if none are available.
7. If a command cannot be run, record the reason, exact missing prerequisite, and next command in `validation-evidence.html`.
8. Mark the stage `passed`, `failed`, `blocked`, or `unverified`; never mark validation passed without evidence.
9. Failed relevant validation blocks implementation review, PR draft, and done until fixed or explicitly overridden by the user.

Review stage contract:

1. Reviewer terminal reads the packet, plan, validation practices, validation plan, validation evidence, implementation log, and diff.
2. Reviewer reads `references/engineering-invariants.md` and any repo-specific invariant docs that exist before writing findings.
3. Reviewer applies the content/intent lens: Jira when present, otherwise plan, chat-captured decisions, PR body, branch behavior, acceptance criteria, user/product workflow, and validation evidence.
4. Reviewer applies the engineering-invariant lens: shared invariants, repo-specific invariants, validation/ops/security/privacy/auth/tenancy expectations, and workflow-specific invariants.
5. Every content mismatch or invariant violation is a finding, even when the implementation appears to work.
6. Reviewer treats missing, irrelevant, failed, or hand-waved validation as a finding. If the change cannot be trusted without runtime/integration proof, mark it blocker.
7. Reviewer writes structured findings to the exact path from `review-handoff.html` or `watch-prompts.html`:
   - `review-plan-findings.html`,
   - `review-implementation-findings.html`,
   - `review-pr-findings.html`.
8. Reviewer writes the findings artifact even when there are no issues. In that case, include "No blocker findings", files reviewed, content/intent checked, invariants checked, validation checked, residual risk, and timestamp.
9. Reviewer updates `review-handoff.html` to `review complete` or `blocked` and records the findings file path.
10. Findings use `Applied: pending|yes|partial|reject` as the resume cursor and include `Invariant: none|<name/path/section>`.
11. Reviewer terminal never edits code.

Apply-review contract:

1. Implementer terminal reads `review-handoff.html` and the relevant findings artifact before advancing.
2. If the findings artifact is missing but review was expected, stop and wait or ask the user whether to proceed without reviewer output.
3. Implementer terminal walks pending findings.
4. Implementer decides apply, partial, or reject.
5. Escalate only for ambiguity, scope expansion, product judgment, or red validation.
6. Update findings disposition and notes.
7. Re-run targeted validation for applied implementation/PR findings and append the result to `validation-evidence.html`.
8. Update `review-handoff.html` to record applied, rejected, deferred, or blocked disposition.
9. Do not auto-commit or auto-push unless the user has approved that specific external write gate.

## Capture Mode

Goal: preserve useful implementation context from the current chat when the work did not start with a formal plan or Jira ticket.

Use this mode when the user says the work started in chat, asks to capture the current conversation, or wants a review packet for work that has no durable artifact yet.

Steps:

1. Create or resolve a stable work item slug:
   - use the user's requested name when provided,
   - otherwise use the current branch name if it is descriptive,
   - otherwise derive a short slug from the problem statement.
2. Create `context/work-items/<slug>/` if needed.
3. Write or update `anchors.html` with primary anchor type `chat`.
4. Write `chat-capture.html` from the available conversation. If the relevant earlier chat is not in context, do not invent it; ask the user to paste the missing thread or give a short summary.
5. Capture:
   - user goal and business/product reason,
   - decisions made in chat,
   - scope included and explicitly excluded,
   - assumptions and unresolved questions,
   - repos/files/services mentioned,
   - implementation steps already taken or planned,
   - validation evidence mentioned,
   - links or identifiers mentioned in the chat.
6. If currently inside a target repo, read `git status`, branch name, and changed file list to enrich the capture. Do not inspect large diffs unless needed for a packet.
7. Write or update `context-packet.html` from the chat capture and repo/service graph.
8. If the user asked for review handoff, also write `reviewer-packet.html` immediately.
9. Append a short row to `activity.html`.

Use this section structure inside `chat-capture.html`:

```text
# Chat Capture: <slug>

## Source
- Captured:
- Captured from: current chat | pasted chat summary | other
- Jira: <KEY | not created yet | draft only>
- Plan: <path or none>
- PR/Branch: <value or none>

## User Goal
## Why This Matters
## Decisions Made In Chat
## Scope
## Explicit Non-Goals
## Repos / Services Mentioned
## Files Mentioned Or Changed
## Implementation Notes
## Validation Mentioned
## Assumptions
## Open Questions
## Suggested Durable Summary
```

The suggested durable summary should be suitable for pasting into Jira, a PR description, or a Confluence note. Do not rely on "as discussed above" because another engineer will not have the chat.

If chat context is thin, ask at most three focused questions before writing the packet:

1. "What should this work item be called?"
2. "Which repo/branch contains the implementation?"
3. "What is the intended behavior change?"

## Context Mode

Goal: create `context-packet.html` from Jira, an existing plan, a chat capture, or a natural-language work request.

Steps:

1. If a ticket ID is present, fetch Jira issue through Atlassian tools.
2. If a plan path/name is present, read plan artifacts first:
   - `context/plans/active/<name>/plan.html`
   - legacy `context/plans/active/<name>/plan.md` only when no HTML plan exists
   - `research.html`
   - `analysis.html`
   - legacy `research.md` / `analysis.md` when no HTML artifact exists
   - legacy `handoff.md` / `progress.md` when present
3. If a chat-first work item is present, read `chat-capture.html`.
4. Read linked tickets, linked Confluence pages, comments, and remote PR links when Jira context exists.
5. Extract decisions, acceptance criteria, open questions, and scope changes.
6. Map likely repos/services using:
   - ticket text,
   - plan text,
   - chat-capture text,
   - linked PRs,
   - config repo list,
   - repo/service graph,
   - known domain terms.
7. If ambiguity remains, ask up to 3 focused questions:
   - target product surface,
   - expected repo/service owner,
   - review depth or implementation intent.
8. Update `anchors.html`.
9. Write `context-packet.html`.
10. Append a short row to `activity.html`.

Use this section structure inside `context-packet.html`:

```text
# Context Packet: <ticket or slug>

## Work Item
## Anchor
Jira: <KEY | not created yet | draft only>
Plan: <path or none>
Chat Capture: <path or none>
## Context Conflicts
## Problem / Goal
## Acceptance Criteria
## Key Decisions And Open Questions
## Linked Context
## Likely Repos
## Service Interaction Map
## Files To Inspect First
## Risks / Review Focus
## Recommended Next Step
```

## Review-Packet Mode

Goal: create a portable `reviewer-packet.html` for another engineer and their agent.

Steps:

1. Resolve the work item and read `anchors.html` if present.
2. Read plan artifacts for any plan anchor.
3. Read `chat-capture.html` for any chat anchor.
4. Read Jira/Confluence/linked PR context for any Jira anchor.
5. Read PR details with `gh pr view` when possible.
6. Find new Jira/plan/chat/PR anchors in PR title/body/branch and add them to `anchors.html`.
7. If no Jira exists, do not create it inside review-packet mode. Use plan or chat context, record `Jira: not created yet` or `Jira: opted out by user`, and recommend `jira` mode if tracking was not opted out.
8. Read local git diff and changed file list if in the PR repo.
9. Identify cross-repo context:
   - services called by the changed code,
   - shared APIs/contracts,
   - UI-middle-backend flow,
   - named repo-context flows,
   - config or deployment dependencies,
   - tests/evals/runtime proof needed.
10. If the work is multi-repo, multi-service, or ownership is unclear, use the `repo-context` skill to create or refresh `cross-repo-context.html` in the work item folder before writing the reviewer packet.
11. Read `validation-plan.html` and `validation-evidence.html` when present.
12. If validation evidence is missing or weak for the changed behavior, call that out as a validation gap instead of implying the work is proven.
13. Write `reviewer-packet.html`.
14. If there are missing repos, include checkout commands.
15. End with the exact prompt another engineer can give their agent.

Use this section structure inside `reviewer-packet.html`:

```text
# Reviewer Packet: <ticket / PR>

## Review Objective
## Jira Context
## Plan Context
## Chat Context
## Context Conflicts
## PRs / Branches
## Repos To Check Out
| Repo | Relevance | Why Needed | If Missing | Branch / PR | Files To Read |
|---|---|---|---|---|---|

## Cross-Repo Context
## Service Interaction Map
## Files To Read First
## Engineering Invariants To Enforce
## Implementation Summary
## Validation Plan / Required Proof
## Validation Evidence
## Validation Gaps
## Known Risks
## Review Instructions For Your Agent
## Suggested Review Order
```

Review instructions should be direct:

```text
Review this PR using reviewer-packet.html. Read the listed repos/files first.
If a repo is missing, tell me the checkout command before proceeding.
Do not modify files. Report blockers first, then should-fix items, then nits.
Apply two mandatory review lenses:
- content/intent: Jira intent when present, otherwise plan/chat decisions, PR body, acceptance criteria,
  user/product workflow, cross-repo contracts, and validation evidence.
- engineering invariants: shared engineering invariants and repo-specific invariants.
Treat missing, irrelevant, failed, or hand-waved validation as a finding.
Treat violations of observability, alerting/dashboard coverage, DRY/reuse, maintainability,
readability, scalability planning, exception handling, tests, docs, security, privacy, auth,
tenancy, and performance expectations as findings.
```

## Plan Mode

Goal: interview the user, create or link the HTML-first plan, and co-create the validation plan before implementation starts.

Steps:

1. Resolve the plan path, plan name, Jira ticket, chat capture, work item, or short problem statement.
2. Prefer existing Workbench plan artifacts under `context/plans/active/<name>/`, but still check whether validation and open questions need a fresh interview pass.
3. Create or update `context/work-items/<plan-slug>/`.
4. Read relevant context first: `context-packet.html`, Jira/Confluence links, chat capture, service graph, target repo docs, `references/validation-practices.md`, and repo-native validation signals.
5. Interview the user in focused rounds. Cover:
   - intended behavior and success criteria,
   - scope and non-goals,
   - affected repos/services/contracts,
   - important design constraints or alternatives,
   - rollout, observability, alerting/dashboard needs,
   - risks, scalability, exception handling, and compatibility,
   - validation bar: what API calls, data checks, tests, runtime checks, Docker/container proof, manual proof, evals, or cross-repo contract checks prove the change works.
6. Use the environment's user-question tool for the interview:
   - Claude Code: `AskUserQuestion`,
   - Codex: `request_user_input` when available,
   - fallback: ask the same focused question in chat and wait.
7. For validation, the agent proposes concrete options from repo-native signals and QA practices, then asks the user to confirm the bar. If the user says to choose, record that explicit delegation and the assumptions.
8. Write `planning-interview.html` with the user's answers, agent recommendations, confirmed validation bar, delegated decisions, and open questions.
9. When creating or revising a plan, read `context/standards/html-plan-standard.md` and create `plan.html` as the primary artifact.
10. Include the confirmed validation strategy in `plan.html`: behavior to prove, target test layer, API/data calls, Docker/container proof, runtime/manual proof, happy path, edge cases, negative/failure cases, cross-repo contract checks, and known gaps.
11. Create or update `validation-plan.html` from `planning-interview.html`, not from implementation-time guessing alone.
12. Choose the implementation breakdown shape:
   - Default: create a small-PR breakdown without asking again when code changes are non-trivial.
   - Bypass: only use a coarse/single-PR breakdown when the user explicitly requested it or the plan is so small that splitting would create review noise. If bypassing, show the default split and record why the coarse path is acceptable.
13. Create `pr-breakdown.html` using the implementation-plan pattern from `https://thariqs.github.io/html-effectiveness/16-implementation-plan.html` and adapt `assets/pr-breakdown-worktree-contract.html` when useful. Include the visible `PR Breakdown And Worktree Contract` section, PR/slice title, purpose, dependencies, estimated meaningful lines, related files, base repo path, base branch, branch/worktree suggestion, exact `wt-feature` setup command or script fallback, parallelizable/sequential status, validation, stop rules, and reviewer focus.
14. If more than one slice can run in parallel or if another engineer needs setup commands, create `worktree-plan.html` with base-repo `wt-feature` commands and dependency order.
15. Link the plan in `anchors.html`, `context-packet.html`, and `activity.html`.
16. Draft `jira-draft.html` by default unless the user opted out. Do not create or update Jira externally without explicit approval. If the user opted out, record `Jira: opted out by user` and do not keep asking for Jira on this work item.

Use this section structure inside `planning-interview.html`:

```text
# Planning Interview: <slug>

## Source
## User Goal
## Success Behavior
## Scope
## Non-Goals
## Repos / Services / Boundaries
## Key Design Choices
## PR Breakdown Preference
## Risks And Rollout
## Validation Bar Confirmed With User
## Agent-Recommended Validation Options
## User-Confirmed Validation Plan
## Open Questions
## Assumptions / Delegated Decisions
```

Validation interview prompt:

```text
Here is the validation bar I recommend based on the repo and risk:
- unit/contract:
- explicit API/data calls:
- Docker/containerized runtime:
- integration/runtime:
- UI/manual:
- happy path:
- edge/negative cases:
- cross-repo:
- telemetry/observability:

Which of these should be required before PR handoff, and is anything missing?
```

Close with one of:

- next: `review-packet` when implementation/PR exists,
- next: `context` when more repo/service context is needed,
- next: `jira` when the plan should become a ticket.

## Jira Mode

Goal: draft, create, or update a Jira ticket from an existing plan, chat capture, or work item. Jira tracking is the default team-visible record unless the user opted out.

Steps:

1. Read the plan/chat/work item context and `anchors.html`.
2. If `anchors.html` records `Jira: opted out by user`, do not draft or create Jira unless the user explicitly re-enables it. Record the opt-out in `activity.html`.
3. Draft `jira-draft.html` with:
   - summary,
   - problem statement,
   - acceptance criteria,
   - affected repos/services,
   - links to plan/context packets,
   - suggested project key from `config.yaml`.
4. If a Jira ticket already exists, draft the update needed to align it with the current plan, packets, validation bar, and PR state.
5. Ask for explicit approval before creating or updating Jira.
6. If approved, use Atlassian tools to create or update the Jira issue.
7. Keep the existing work-item slug.
8. Update `anchors.html`, `jira.html`, `context-packet.html`, and `activity.html` with the new key/link or update status.

Never create or update Jira silently. Drafting locally is safe; Jira writes need explicit approval.

## Review Mode

Goal: review a PR/branch from a reviewer packet, without editing files.

Steps:

1. Read `reviewer-packet.html`.
2. Read `references/engineering-invariants.md`.
3. Re-enumerate and read repo-specific invariant docs when present:
   - `context/agent-flow/invariants.html`,
   - legacy `context/agent-flow/invariants.md`,
   - target repo `knowledge-base/invariants/*.md`,
   - target repo `docs/invariants/*.md`,
   - relevant `AGENTS.md` or `WORKFLOW.md`.
4. Check local availability of required repos.
5. If a primary/context repo is missing, stop and list checkout commands before reviewing.
6. Read the files named in `Files To Read First`.
7. Read `validation-plan.html` and `validation-evidence.html` when present; otherwise use the packet's validation sections.
8. Read the PR diff or branch diff.
9. Review in this order:
   - content/intent from Jira when present, otherwise plan intent, chat-captured decisions, PR body, branch behavior, acceptance criteria, and user/product workflow,
   - engineering invariants and repo-specific invariants,
   - changed repo correctness,
   - cross-repo/service contract fit,
   - validation evidence,
   - observability, alerting/dashboard coverage, scalability planning, exception handling, maintainability, readability, and DRY/reuse,
   - security/performance/operational risk,
   - missing tests or manual proof.
10. If validation evidence is missing, failed, irrelevant, or too narrow for the risk, create a finding and list the exact validation needed.
11. Write `external-review-findings.html`.

Use this section structure inside `external-review-findings.html`:

```text
# External Review Findings: <ticket / PR>

## Summary

## Findings
### F1 - [blocker|should-fix|nit] <short title>
**Where**:
**Packet section**:
**Invariant**: none|<name/path/section>
**Issue**:
**Recommendation**:
**Applies to repo**:
**Needs author response**: yes|no
**Author disposition**: pending
**Author notes**:

## Validation Gaps
## Follow-Up Tickets Suggested
```

If no issues are found, say that clearly and still list content/intent checked, invariants checked, validation checked, and residual risk/test gaps.

## Pair Mode

Goal: let the user run Claude and Codex manually, Helix-style, against shared Workbench artifacts so they can review each other's plans and implementations.

This mode does not need a daemon. It prepares the shared files and role prompts, then the user starts Claude/Codex sessions themselves.

Role assignment should be easy for the user. If the user did not already say which session owns implementation and which owns review, ask exactly one question before creating prompts:

```text
Which visible session should implement, and which should review?

Reply in one line, for example:
- Claude implements, Codex reviews
- Codex implements, Claude reviews
- Claude and Codex both review, no implementer yet
```

Use the tool-native question primitive when available: Claude Code `AskUserQuestion`; Codex `request_user_input` when available; otherwise ask in chat and wait. Do not make the user learn the state-machine vocabulary. Translate their answer into the `Implementer` and `Reviewer` fields in `review-handoff.html`.

Steps:

1. Resolve the work item, plan, PR, or branch.
2. Prefer local Workbench artifacts if present. If not present, create the work item folder and packets first.
3. Ask or confirm role assignment when missing:
   - implementer session,
   - reviewer session,
   - whether this is single-reviewer, swapped roles, or cross-review.
4. Create or update:
   - `chat-capture.html` when chat-first context is the source,
   - `context-packet.html`
   - `validation-plan.html`
   - `validation-evidence.html` when validation has already run
   - `reviewer-packet.html`
   - `review-handoff.html`
   - `paired-agent-prompts.html`
   - `activity.html`
5. Decide the stage:
   - `plan-review`: one agent authored plan, the other reviews plan.
   - `implementation-review`: one agent implemented, the other reviews diff against packet/plan.
   - `cross-review`: both agents independently review and write findings.
6. Write prompts for both roles. The section labels must match the user's assignment, for example `Claude Implementer Prompt` and `Codex Reviewer Prompt`, or the reverse.
7. Tell the user exactly what to run in each terminal.

Use this section structure inside `paired-agent-prompts.html`:

```text
# Paired Agent Prompts: <work item>

## Shared Context
- Work item:
- Plan:
- Packet:
- Target repo/branch:

## Role Assignment
- Implementer session:
- Reviewer session:
- Review mode:

## Claude Prompt
<copy-paste prompt>

## Codex Prompt
<copy-paste prompt>

## Expected Outputs
- review-handoff.html
- review-plan-findings.html
- review-implementation-findings.html
- external-review-findings.html
- validation-evidence.html

## Conflict Resolution
If findings disagree, author summarizes both and chooses accepted/rejected/deferred.
```

Default reviewer prompt:

```text
You are the reviewer. Read the shared packet and the listed files first.
Read review-handoff.html and write your review to the exact findings path named there.
Read and enforce the engineering invariants and any repo-specific invariant docs.
Do not modify files. Apply two mandatory review lenses:
- content/intent: Jira intent when present, otherwise plan/chat decisions, PR body,
  acceptance criteria, user/product workflow, cross-repo contracts, validation plan,
  and validation evidence.
- engineering invariants: shared engineering invariants, repo-specific invariants,
  validation/ops/security/privacy/auth/tenancy expectations, and operational risk.
Treat missing, failed, irrelevant, or too-narrow validation as a finding.
Treat weak scalability planning and weak exception handling as findings, not follow-up polish.
Write findings to the path specified in review-handoff.html, even if there are no issues.
If there are no issues, write a no-findings artifact with files reviewed, content/intent checked,
invariants checked, validation checked, residual risk, and timestamp.
Report blockers first, then should-fix items, then nits.
```

Default implementer/apply prompt:

```text
You are the implementer. Read the shared packet and the reviewer findings.
Before starting the next PR slice, read review-handoff.html and the findings file named there.
If the reviewer is following along but the findings file is missing or still pending, wait
or ask the user whether to proceed without reviewer output.
Apply only accepted findings or straightforward blockers within scope.
Do not broaden scope without asking. Update the findings disposition and rerun
targeted validation. Append command, working directory, exit status, and result summary
to validation-evidence.html.
```

Pair mode should also include a portability note: if another engineer lacks Workbench, publish mode can copy the reviewer packet summary into Jira/PR.

## Publish Mode

Goal: make the locally generated packet available to engineers who do not have this Workbench.

Steps:

1. Read `context-packet.html` and/or `reviewer-packet.html`.
2. Include `chat-capture.html` only as a concise durable summary, never as a raw transcript dump.
3. Read `validation-plan.html` and `validation-evidence.html` when present.
4. Create a concise Jira/PR-safe "Agent Review Packet" section with validation evidence or explicit validation gaps.
5. Prefer PR body/comment for review-specific context.
6. Prefer Jira description/comment or linked Confluence for durable product/work context.
7. Ask for explicit approval before writing to Jira or GitHub.
8. After approval, use available tools/CLI to update Jira/PR.
9. Record the publication target and timestamp in `activity.html`.

Never publish private local-only paths as the only source of truth. If a local path appears, pair it with the relevant Jira/PR/checkout instructions or summarize the content inline.

## Apply Mode

Only apply findings when the user explicitly asks to fix or apply them.

Steps:

1. Read `external-review-findings.html`.
2. Read `validation-plan.html` and `validation-evidence.html` if present.
3. Walk pending findings in order.
4. For each finding:
   - fix blockers that are in scope,
   - fix straightforward should-fix items,
   - ask before scope expansion or product judgment,
   - mark disposition as `accepted`, `rejected`, or `deferred`.
5. Rerun targeted validation from `validation-plan.html` for accepted findings and append results to `validation-evidence.html`.
6. If validation cannot run, mark the work blocked or unverified and record the exact missing prerequisite.
7. Update activity log.

Never apply changes in repos outside the current working directory unless the user explicitly tells you to work in that repo.
