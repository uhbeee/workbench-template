---
name: agent-flow
description: Config-driven visible plan-to-PR workflow for Workbench engineering work. Use for agent-flow, full lifecycle, visible agents, Helix-style implementation, cross-repo context, HTML plans, PR breakdowns, small or stacked PRs, reviewer packets, review from packet, Claude/Codex pairing, worktrees, Jira/PR handoffs, continuation handoffs, or approved bypass of detailed PR slicing.
metadata:
  workbench.argument-hint: "[entrypoint] [mode] (run with no args for the interactive picker)"
---

# Agent Flow

Use this as the single organization-specific skill for plan-to-PR engineering workflows. It is deliberately skill-only: no daemon is required. The skill owns the full lifecycle when requested, reads Workbench context, captures chat context when the work started informally, gathers live Jira/PR data when available, drives visible terminal handoffs, asks focused clarifying questions when needed, and writes portable packet artifacts that another engineer and their agent can use.

## Core Idea

Manage work around durable packets, not around chat sessions.

- Jira is the default team-visible work control plane. The user can opt out or defer Jira, but `agent-flow` should plan to draft/create/update Jira unless told not to.
- A plan can still be the anchor first while the Jira draft is prepared or deferred.
- A chat can be the anchor first when implementation already started before any plan or Jira ticket existed.
- Workbench is the richest local policy and context layer when available.
- The repo/service graph tells agents what other repos and files may matter.
- Jira/PR packet sections make the work portable between developers who do not have Workbench.
- Shared local packets make Claude and Codex able to review each other's plans and implementations.
- The default implementation shape is small, human-readable PR slices with explicit dependencies, validation, branch/worktree guidance, and reviewer focus.
- A larger/coarse implementation path is allowed only when the user explicitly asks to skip the nitty-gritty PR slicing or approves the tradeoff after seeing the risk.
- `full` mode is the end-to-end user-facing lifecycle. It may reuse Forge-style planning internally, but implementation follows Helix-style visible terminal handoffs, not the Workbench `implement` skill.
- Background automation can come later; the first-class flow is human-controlled, visible, and review-packet driven.

## Workflow Ownership

`agent-flow` is the public entry point for this workflow.

- Use Forge-style planning as an internal planning stage when no plan exists.
- Use Helix-style implementation as the internal execution stage after plan review is accepted.
- Use visible Claude/Codex terminal sessions for independent plan and implementation review.
- Use ship-style behavior to draft PR/Jira updates, with external Jira/GitHub writes still gated on explicit approval.

Do not use the Workbench `implement` skill for this lifecycle. Do not start headless/background agents for implementation or review. If the environment cannot execute a stage directly, write the exact visible-terminal prompt/command in `paired-agent-prompts.md`, `watch-prompts.md`, or `lifecycle.md` and stop at the gate.

## Start Here Every Time

1. Read Workbench root from `config.yaml`, `~/.codex/workbench-root`, or `~/.claude/workbench-root`.
2. Read `config.yaml` for Jira projects, GitHub org/repos, worktree root, Confluence spaces, and Slack channels.
3. Read optional context files if present:
   - `context/repo-context/*.yaml`, preferably through the `repo-context` skill/helper for scoped output
   - `context/agent-flow/repos.yaml`
   - `context/agent-flow/services.yaml`
   - `context/agent-flow/invariants.md` with legacy `invariants.md` fallback
   - `context/agent-flow/workflows/default.md` with legacy `default.md` fallback
4. Determine the supplied entrypoint, if any:
   - Jira ID, e.g. `PROJ-1234`
   - GitHub PR URL or PR number
   - branch name
   - packet path, e.g. `context/work-items/PROJ-1234/reviewer-packet.md` (Markdown-first default) or `reviewer-packet.html` when the packet has visual review flow
   - Forge/workbench plan path
   - Forge/workbench plan name
   - current chat or pasted chat summary
   - full lifecycle request
   - watcher resume request
   - vague natural language request
5. Determine the supplied mode, if any.
6. If either entrypoint or mode is missing, run the interactive intake gate before reading Jira/PR details or writing artifacts.
7. After the user has confirmed both entrypoint and mode, continue with the selected mode.

## Interactive Intake Gate

Most day-to-day usage should support a bare `/agent-flow` invocation. If the user omits the entrypoint, the mode, or both, stop and ask for the missing pieces with a concise menu. Do not silently infer and continue.

Only skip this gate when the user explicitly supplied both:

- an entrypoint: what work item or source to operate on,
- a mode: what `agent-flow` should do with it.

If one value is present, show it as detected and ask for the missing value. If a default is obvious, mark it as recommended, but still wait for the user's choice or confirmation.

Use this prompt shape:

```text
I need two choices before agent-flow starts.

Entrypoint: what should this work be anchored on?
- Current chat or pasted summary: capture this conversation as the source of truth.
- Short problem statement: start from a named feature/problem with no durable artifact yet.
- Jira ticket: use a tracked requirement such as PROJ-1234.
- Existing plan: use a Workbench/Forge plan path or plan name.
- Work item folder: resume context/work-items/<slug>.
- Reviewer packet: review from an existing `reviewer-packet.html` (when the packet uses visual flow) or `reviewer-packet.md` (when it is text-heavy).
- PR or branch: prepare/review work from code that already exists.

Mode: what should agent-flow do?
- full: run the visible plan -> review -> implement -> review -> packet -> PR draft lifecycle.
- context: gather Jira/plan/chat/repo context into a context packet.
- plan: create or link a Markdown-first implementation plan (HTML companion only when the plan has substantial visual content per the standard).
- capture: preserve chat-started work as a durable work item.
- pair: prepare visible Claude/Codex prompts for plan or implementation review.
- watch: advance an existing visible two-terminal pipeline.
- review-packet: create a portable packet for another engineer or agent.
- review: review from a packet or PR without editing files.
- apply: apply accepted external findings when explicitly requested.
- jira: draft/create/update Jira from a plan/chat/work item after approval; default unless the user opts out.
- publish: draft or apply Jira/PR packet updates after approval; skip Jira updates when the user opted out.
- handoff: create a restartable continuation prompt and/or Workbench handoff artifacts.
- status: show where an existing work item stands.

Reply with the entrypoint and mode, for example:
`current chat + capture`, `PROJ-1234 + full`, or `context/work-items/foo + watch`.
```

If the invocation is `/agent-flow` with no arguments, ask for both entrypoint and mode. If the invocation is `/agent-flow PROJ-1234`, ask for mode and recommend `context` for discovery or `full` for plan-to-PR. If the invocation is `/agent-flow full`, ask for the entrypoint.

## Context Resolution Order

Always use the richest available context first, then publish/summarize it outward for portability.

1. **Local Workbench context**, when the path exists:
   - `context/work-items/<id-or-slug>/`
   - `context/plans/active/<name>/`
   - `context/repo-context/*.yaml` or generated `cross-repo-context.html` snapshots
   - `context/agent-flow/*.yaml`
   - `context/agent-flow/invariants.md` with legacy `invariants.md` fallback
   - local `chat-capture.md`
   - local `reviewer-packet.md` (or `reviewer-packet.html` when the packet has visual flow), `context-packet.md`, `external-review-findings.md`
2. **Local target repos/worktrees**, when present:
   - current git worktree,
   - repos under `config.yaml: worktrees.root`,
   - files listed by packet/plan/service graph.
   - repo-specific rule entrypoints listed by repo-context, such as `AGENTS.md`, `CLAUDE.md`, and `.agents/instructions/*.instructions.md`.
3. **Jira/Confluence/GitHub/PR context**, when available through tools.
4. **Portable packet context embedded in Jira/PR**, when local Workbench context is missing.

If Workbench context exists, use it as the source of truth and generate Jira/PR summaries from it. If Workbench context does not exist, reconstruct enough context from Jira/PR packet sections to proceed.

## Modes

| Mode | Use When | Primary Output |
|---|---|---|
| `full` | User wants the whole visible plan-review-implement-review-packet-PR lifecycle | `lifecycle.md` + `pipeline.md` + HTML stage artifacts |
| `watch` | User has a work item and wants the visible Helix-style terminal handoff to advance | next pipeline row |
| `capture` | Work started from chat without a plan/Jira, or the user asks to preserve chat context | `chat-capture.md` + optional packet |
| `context` | Starting from Jira or an ambiguous feature | `context-packet.md` |
| `plan` | Interviewing the user, creating/linking an HTML plan, and confirming validation before implementation | `planning-interview.md` + `plan.md` + `validation-plan.md` |
| `review-packet` | Preparing a PR/branch for another engineer or their agent to review | `reviewer-packet.md` (or `.html` when the packet has visual review flow) |
| `review` | Reviewing from a packet or PR context | `external-review-findings.md` |
| `apply` | Applying accepted external findings | updated findings + code changes when explicitly requested |
| `jira` | Drafting, creating, or updating a Jira ticket from a plan, chat capture, or work item unless the user opted out | `jira-draft.md` or Jira ticket link |
| `pair` | Preparing Claude/Codex to review each other's plan or implementation | role prompts + shared packet paths |
| `publish` | Copying packet summaries into Jira/PR after approval | Jira/PR update draft or applied update |
| `handoff` | Current session is losing context, a visible session needs a restart prompt, or the user asks to save/update continuation state | `handoff.md` + `continuation-prompt.md` or copy-paste prompt |
| `status` | Checking where a work item stands | short status summary |

Mode recommendations when the mode is missing:

- Jira ID only -> `context`
- PR URL/number -> `review-packet`
- packet path -> `review`
- plan path/name -> `plan`, then recommend context or review-packet next
- "full workflow", "whole workflow", "plan implement review", "end to end", or "plan to PR" -> `full`
- "watch", "resume watcher", "advance pipeline", "visible agents", "no headless", or "Helix-style implementation" -> `watch` if a work item exists, otherwise `full`
- "capture this chat", "started from chat", "no plan", or "preserve this context" -> `capture`
- "review this" + packet/PR -> `review`
- "Claude and Codex", "two agents", or "review each other's" -> `pair`
- "add this to Jira/PR" or "make it portable" -> `publish`
- "handoff", "continuation prompt", "next session", "losing context", "update plan/progress", or "save where we are" -> `handoff`
- vague "orchestrate this" -> ask for plan, Jira ID, PR, or short problem statement, and note that Jira tracking is the default unless opted out

These are recommendations for the intake prompt, not permission to proceed without the user's mode choice.

## Jira Tracking Contract

Jira tracking is default-on because it is the portable team-visible record. Default-on does not mean silent external writes.

- Default: create or update `jira-draft.md` from the plan, chat capture, context packet, or work item, then ask for explicit approval before creating or updating Jira.
- Existing Jira: read it, keep `jira.md` current, and draft any Jira update needed to keep the ticket aligned with the plan and review packets.
- No Jira yet: draft one unless the user says not to, then offer Jira creation at the next approval gate.
- Opt-out phrases include "no Jira", "do not create Jira", "do not update Jira", "skip Jira", "local only", and "no ticket".
- If the user opts out, record `Jira: opted out by user` in `anchors.md`, context packets, plans, publish artifacts, and handoffs. Do not keep asking for Jira on that work item unless the scope changes or the user asks.
- If the user defers Jira, record `Jira: deferred until <gate>` and prepare only local summaries until that gate.
- If Jira is not available because tools/auth are missing, record `Jira: draft only` and include the exact next action needed to publish it later.
- Reviewers still review content/intent from the available source of truth: Jira when present, otherwise plan, chat capture, PR body, branch behavior, and acceptance criteria.

Never create or update Jira silently. Drafting local HTML artifacts is safe; external Jira writes need explicit approval.

## Work Item Layout

Use one folder per work item. If there is no Jira ticket yet, use a stable slug from the plan name, chat summary, branch, or problem statement.

```text
context/work-items/<JIRA-ID-or-plan-or-chat-slug>/
  anchors.md
  chat-capture.md
  jira.md
  jira-draft.md
  lifecycle.md
  gates.md
  pipeline.md
  planning-interview.md
  validation-plan.md
  validation-evidence.md
  pr-breakdown.md
  worktree-plan.md              # optional branch/worktree matrix for parallel PR slices
  context-packet.md
  plan.md
  implementation.md
  summary.md
  manual-verification.md
  review-plan-findings.md
  review-implementation-findings.md
  review-pr-findings.md
  reviewer-packet.html          # HTML only when the packet has genuine visual flow (diagrams, mockups, side-by-side); otherwise reviewer-packet.md
  external-review-findings.md
  review-handoff.md
  handoff.md
  continuation-prompt.md
  progress.md                   # optional tracker when handoff/progress state is needed
  paired-agent-prompts.md
  watch-prompts.md
  pr-draft.md
  activity.md
```

If the work already has a Forge plan in `context/plans/active/<name>/`, do not duplicate it. Link to it from the work item folder.

Work-item artifacts follow the Markdown-first default in `context/standards/html-plan-standard.md`: text-heavy strategic content (plans, breakdowns, validation, handoffs, findings) lives in `.md`; HTML companions are added only when the artifact has substantial visual content (architecture diagrams, mockup hierarchy, side-by-side comparisons). `reviewer-packet` is the most common HTML candidate when it has visual review flow. Legacy `.html` artifacts that predate the inversion remain readable; rewrite them as `.md` when you next update them.

## Planning Contract

The planning phase is where `agent-flow` interviews the user and turns intent into a plan, validation strategy, and implementation handoff. Do not treat planning as only "write `plan.md`."

For `full` and `plan` modes:

- Read [validation practices](references/validation-practices.md) before interviewing on validation.
- Create or update `planning-interview.md` before finalizing `plan.md`, `validation-plan.md`, or `pr-breakdown.md`.
- Interview the user in the style of Forge plus Helix: clarify goal, success behavior, scope, non-goals, repo/service boundaries, risks, rollout, observability, and validation.
- Use the tool-native interview primitive: Claude Code `AskUserQuestion`; Codex `request_user_input` when available; otherwise ask the same focused question in chat and wait.
- The agent should help by reading available context and proposing concrete options, but the user should confirm the intended behavior and validation bar.
- Ask focused question batches. Do not ask the user to design every detail up front; propose a default and ask for correction.
- If the user explicitly delegates choices to the agent, record that delegation in `planning-interview.md` and mark assumptions in `plan.md` and `validation-plan.md`.
- Plan review cannot pass until the plan says what will be built and how the result will be proven.

## Visible Agent Handoff Contract

Visible Claude/Codex terminals do not share live stdout or private terminal state. Any cross-agent coordination must happen through the work item folder.

For `full`, `watch`, and `pair` modes:

- Treat `pipeline.md`, `review-handoff.md`, and the relevant findings file as the coordination plane.
- If implementer/reviewer roles are not explicit, ask one short role-assignment question before writing prompts: "Which visible session implements, and which reviews?" Accept answers like "Claude implements, Codex reviews" or "Codex implements, Claude reviews." If the current session already created or changed code, recommend current session as implementer and the other visible session as reviewer, but still record the user's answer.
- Create or update `review-handoff.md` with role assignment, current slice, target repo/branch, reviewer output path, implementer read path, and whether review is pending, complete, blocked, or not running.
- Reviewer prompts must include the exact absolute findings path to write:
  - plan review: `review-plan-findings.md`
  - implementation review: `review-implementation-findings.md`
  - PR review: `review-pr-findings.md`
  - external packet review: `external-review-findings.md`
- Reviewers must write the findings artifact even when there are no issues. A no-issue review still records files reviewed, validation checked, residual risk, and timestamp.
- Reviewers must apply both mandatory review lenses:
  - content/intent: Jira, plan, chat-captured decisions, PR/branch behavior, acceptance criteria, user/product workflow, and validation evidence;
  - engineering invariants: `references/engineering-invariants.md`, repo-specific invariant docs, validation/ops/security/privacy/auth/tenancy expectations, and any workflow-specific invariants.
- A no-issue review still states that both the content/intent lens and engineering-invariant lens were checked.
- Implementers must read the relevant findings artifact and `review-handoff.md` before starting the next PR slice or PR draft. Terminal prose from another agent is not sufficient evidence.
- If the reviewer is following along but no findings artifact exists yet, the implementer must mark review pending in `pipeline.md` / `review-handoff.md` and wait or ask the user whether to proceed without reviewer output.
- If the user pastes reviewer comments in chat, capture them into the relevant findings artifact before applying or rejecting them.

## Continuation Handoff Contract

Use the `handoff` skill when the current session is losing context, when the user asks for a continuation prompt, or when a visible Claude/Codex session needs to pass work to another session.

The continuation handoff should be shaped like the implementer/reviewer prompts in this skill, not like a generic summary. It must say:

- which role the next session has: implementer, reviewer, verifier, debugger, planner, or mixed;
- which Workbench plan/work item is the anchor;
- which repo/worktree paths and branches matter;
- which related repos are primary, context, or optional;
- which code files, tests, repo rules, plan docs, progress docs, and review docs must be read first;
- what has happened so far, including decisions, files changed, validation run, reviewer comments, blockers, and known gaps;
- the exact next task;
- how to validate locally, through unit/integration tests plus Docker/local stack/API/UI proof when relevant;
- where the next session must write progress, validation evidence, or review findings before stopping;
- stop rules that require returning to the user.

Before producing the handoff, the `handoff` skill must ask for the output mode unless the user already chose one:

- copy-paste prompt only,
- Workbench artifacts only,
- both.

Default to **both** for non-trivial work because the prompt helps immediate transfer and Workbench artifacts keep the durable coordination plane current.

For `agent-flow` work items, prefer:

- `handoff.md` as the primary human-readable restart packet;
- `continuation-prompt.md` as the paste target for the next session;
- `progress.md` or `progress.md` when current progress is not already represented clearly in `activity.md`;
- `validation-evidence.md` when verification changed;
- `review-handoff.md`, `watch-prompts.md`, or `paired-agent-prompts.md` when the next session's role or reviewer/implementer contract changed.

## PR Breakdown And Worktree Contract

Small, readable PRs are the default. The breakdown exists so a human reviewer can understand one coherent change at a time and so independent work can happen in separate branches or worktrees without blocking unrelated slices.

For `full` and `plan` modes that lead to code changes:

- Create `pr-breakdown.md` by default after the plan and validation plan are accepted.
- Prefer PRs around one responsibility and one reviewer mental model.
- Target small diffs: ideal about 50 meaningful lines, target under 200, maximum 300 unless the user approves an exception. Exclude generated files and tests from the size estimate, but still include their validation impact.
- Every PR slice must be independently reviewable, buildable, testable, and deployable. It must not require a future PR to make the tree compile or the shipped behavior safe.
- Order dependency-first: schema/data foundation, shared contracts/types, service/domain logic, API, UI, integration/cleanup. Merge or add a compatibility shim when a split would leave a broken intermediate state.
- Make dependencies explicit. A later PR may depend on an earlier PR, but a PR must not depend on code that is only promised in a future PR.
- Identify which slices are parallelizable. Independent slices can use separate branches/worktrees from the same base. Dependent slices should name the prior PR branch as the base and land sequentially.
- Include a branch/worktree suggestion for each slice when implementation will span more than one PR: branch name, base branch, optional worktree path, and whether it can run in parallel.
- When a slice requires work in a repo, use the `worktree-feature-create` skill first. It should call the canonical Workbench Python worktree implementation. Only fall back to base-repo aliases or raw `git worktree` commands when that script is unavailable.
- Include for each PR: title, goal, in-scope, out-of-scope, related files, estimated line count, dependencies, branch/worktree guidance, implementation notes, validation required before PR handoff, stop rules, reviewer focus, and status.
- Use the HTML implementation-plan style: summary strip, milestone/PR timeline, dependency graph, data/service flow where useful, risky contracts or snippets, risk table, open questions, validation, and reviewer focus.
- Include a visible `PR Breakdown And Worktree Contract` section inside `pr-breakdown.md` so reviewers can see the splitting rules, dependency posture, branch/worktree matrix, bypass decision, and stop conditions without reading this skill.
- Adapt `assets/pr-breakdown-worktree-contract.html` when a concrete starting shape helps.

### Implementation execution: delegate to a Workflow (canonical)

Once `pr-breakdown.md` is accepted, the **canonical** way to execute it is autonomous: hand the breakdown to the `plan-to-workflow` skill, which emits a runnable Workflow whose every PR runs `worktree → implement → E2E → review-gauntlet → ship`, with the breakdown's dependency graph as track combinators. Prefer this for the implement+review+land portion of `full`/`watch`.

- Default (autonomous): `plan-to-workflow <plan-dir>` → `Workflow({scriptPath})`. The dependency-ordered tracks run in parallel; each PR is gated (a red/skipped gate halts its track; `ship` lands + tidies). This IS the engineering execution engine — agent-flow's planning/intake/Jira/approval gates stay interactive and unchanged.
- Fallback (interactive, supervised): the visible-agent handoff (`watch`) driving `plan-implement → review-gauntlet → ship` turn-by-turn over the identical stages. Use when the user wants to watch every step, the work is unusually risky, or an autonomous run is blocked and you're hand-finishing.
- The two paths share one gate-chain definition — see `../plan-to-workflow/references/orchestration-model.md`. Do not let them drift.
- **Model policy: spawned agents run Sonnet 4.6.** Every Workflow `agent()` call carries `model: 'sonnet'` (the plan-to-workflow template encodes this), and Agent-tool sub-agents spawned by this skill (research, review, implementation handoffs) pass `model: "sonnet"` unless the user explicitly requests a different model.

The user can bypass detailed PR slicing, but it must be intentional:

- Treat phrases like "bypass the nitty gritty PRs", "single PR", "coarse PR", "one branch", "do not split this up", or "just implement the plan" as a request for a coarse path.
- Before accepting the bypass, show the default small-PR sequence briefly and the proposed coarse alternative. Recommend the small sequence when the work crosses layers, repos, migrations, auth/tenant/security boundaries, generated contracts, or high-risk runtime behavior.
- If the user approves the bypass, record it in `planning-interview.md`, `gates.md`, and `pr-breakdown.md` with the reason, residual review risk, validation implications, and the fallback split to use if implementation grows.
- Even in bypass mode, keep the artifact human-readable: use milestones and validation gates instead of a dense task dump.
- Do not use bypass mode to hide uncertainty. If a missing decision affects architecture, validation, rollout, or scope, return to planning first.

Use this section structure inside `planning-interview.md`:

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

## Validation Contract

Validation is a first-class gate. `agent-flow` must give implementers and reviewers a concrete way to decide whether the code works.

For `full`, `watch`, `plan`, `review-packet`, `review`, and `pair` modes:

- Read [validation practices](references/validation-practices.md) when creating or reviewing validation artifacts.
- Create or update `validation-plan.md` during the planning interview when code will be changed or reviewed. Do not rely on implementation-time guesswork as the primary source.
- Have the agent propose repo-native validation options, then have the user confirm the validation bar. If the user delegates confirmation, record that explicitly.
- Create or update `validation-evidence.md` after implementation, after accepted review fixes, and before PR handoff.
- Prefer repo-native validation commands discovered from `AGENTS.md`, `WORKFLOW.md`, README files, package scripts, Makefiles, CI config, existing test docs, and nearby changed-file patterns.
- Use targeted validation by default: focused tests, type/lint/static checks, integration checks, evals, API/runtime smoke tests, or UI/browser checks that directly prove the changed behavior.
- Prefer explicit API/tool/runtime calls to fetch or verify data needed for the scenario. Code inspection alone is not runtime validation.
- Use Docker Compose or Testcontainers-style proof when the behavior depends on a database, queue, cache, external service dependency, or realistic local stack.
- For UI/browser validation, follow the browser validation tool order in `validation-practices.md`: Codex browser-use/Browser skill, Claude-in-Chrome/Chrome MCP, Playwright MCP, Playwright CLI, then explicit user handoff if none are available.
- Include happy path, edge case, and negative/failure coverage when the scenario is non-trivial.
- Add broader suites only when the blast radius justifies them or the repo requires them.
- For cross-repo changes, validate the changed repo and any directly affected contract boundary. If another repo cannot be run locally, record the gap and the exact command or checkout needed.
- Evidence must include command, working directory, timestamp, exit status, scope, and result summary.
- If validation cannot run, mark the gate `blocked` or `unverified`; do not mark the work done just because code was edited.
- A PR draft, reviewer packet, or publish summary must include validation evidence or an explicit user-approved exception.

Use this section structure inside `validation-plan.md`:

```text
# Validation Plan: <slug>

## Behavior To Prove
## Repo-Native Signals Checked
## Required Commands
| Repo | Command | Working Directory | Proves | Required Before |
|---|---|---|---|---|

## Runtime / Integration Proof
## Manual Verification
## Cross-Repo Contract Checks
## Known Gaps
```

Use this section structure inside `validation-evidence.md`:

```text
# Validation Evidence: <slug>

## Summary
Status: pending|passed|failed|blocked|unverified

## Commands Run
| Time | Repo | Command | Working Directory | Exit | Result |
|---|---|---|---|---|---|

## Runtime / Integration Evidence
## Manual Verification Evidence
## Gaps Or User-Approved Exceptions
## Next Validation Step
```

## Work Item Identity

The work item folder slug is stable. Do not rename or move `context/work-items/<slug>/` just because a Jira ticket or PR is created later.

Identity rules:

1. If starting from Jira, default slug is the Jira key, e.g. `PROJ-1234`.
2. If starting from a plan, default slug is the plan name, e.g. `xyz`.
3. If starting from chat, default slug is a short problem slug from the chat, current branch, or the user's stated name.
4. If starting from a PR with Jira, default slug is the Jira key.
5. If starting from a PR without Jira but with a plan or chat anchor, default slug is that existing anchor slug.
6. If a later Jira ticket is created for a plan-first or chat-first work item, keep the original slug and record Jira as an added anchor.
7. If the user explicitly asks to rename a work item, create a redirect note in the old folder before moving anything.

Maintain `anchors.md` in each work item:

```text
# Anchors: <slug>

## Primary Anchor
- Type: chat|plan|jira|pr|branch|manual
- Value:
- Reason:

## Linked Anchors
| Type | Value | Source | Added |
|---|---|---|---|
| plan | context/plans/active/xyz/plan.md | initial | YYYY-MM-DD |
| chat | context/work-items/xyz/chat-capture.md | initial | YYYY-MM-DD |
| jira | PROJ-1234 | created later | YYYY-MM-DD |
| pr | repo#123 | linked later | YYYY-MM-DD |

## Context Precedence
1. Local Workbench plan/context packet
2. Chat capture when no plan exists, or as decision history behind the plan
3. Jira acceptance criteria/comments
4. PR implementation details
5. Published packet fallback
```

When generating packets, read all anchors. Do not choose Jira OR plan. Use both:

- Plan context answers "what did we intend to build and why?"
- Chat context answers "what did we decide informally before durable artifacts existed?"
- Jira context answers "what is the team-visible tracked requirement and latest discussion?"
- PR context answers "what actually changed?"

If plan, chat capture, and Jira conflict, call it out in the packet under `Context Conflicts` and ask before treating any source as authoritative.

Jira tracking defaults to create/update, but it may be opted out or deferred. Record one of:

- `Jira: <KEY>` when a ticket exists,
- `Jira: not created yet` when plan-first or chat-first,
- `Jira: draft only` when `jira-draft.md` exists but no ticket has been created,
- `Jira: deferred until <gate>` when the user wants Jira later,
- `Jira: opted out by user` when the user explicitly does not want Jira for this work item.

## Repo And Service Graph

Use the `repo-context` skill when present. Its bundled helper command is:

```bash
python3 <workbench-root>/.agents/skills/repo-context/scripts/repo_context.py explain --current --include-adjacent
```

Use `context/repo-context/*.yaml` and generated `cross-repo-context.html` snapshots as the richer source of truth for repo, service, product, infrastructure, App Insights, and validation context. Keep legacy `context/agent-flow/repos.yaml` and `context/agent-flow/services.yaml` as compatibility inputs; repo-context reads them so older packets do not diverge.

For multi-repo, multi-service, or unclear-ownership work, create or refresh `context/work-items/<item>/cross-repo-context.html` before plan review, implementation review, or PR packet handoff. Use the `repo-context` skill as the entrypoint and let its bundled script generate the scoped snapshot.

The graph should help answer:

- Which repos are involved?
- Which repo owns the UI, middle tier, backend, MCP server, Runtime, or shared contract?
- What files should a reviewing agent inspect first?
- What checkout command should another engineer run if the repo is missing?
- Which services talk to each other?
- Which product/user workflows are affected?
- Which named end-to-end flows and contracts are affected?
- Which App Insights app/env/workflow should be used for telemetry?
- Which validation profile proves the scoped change?

When uncertain, classify repo relevance:

- `primary`: changed repo or directly owned surface.
- `context`: repo likely needed to understand service contracts.
- `optional`: useful background but not required for review.

Do not list every repo by default. Prefer 2-4 high-signal repos with reasons.
Use the repo-context budget by default: current repo, matched services, one-hop adjacent services when useful, affected products, observability hints, and validation recipes.

## Repo-Specific Rules

Repo rules are mandatory inputs, not background reading. Before planning, reviewing, editing, or writing prompts for a target repo:

1. Resolve the repo through the `repo-context` skill when available. Its bundled helper command is:

```bash
python3 <workbench-root>/.agents/skills/repo-context/scripts/repo_context.py explain --repo <repo> --include-adjacent
```

2. Read repo rule entrypoints from repo-context:
   - `repo_rule_entrypoints`
   - `instruction_dirs`
   - `context_files`
   - service-level `inspect_first`
3. If the repo has an instruction directory, read the global/default instruction first, then only the topic-specific instruction files that match the work area.
4. Record the repo rules read in the generated packet (`context-packet.md`, `plan.md`, `reviewer-packet.md` or `.html`, or `pr-breakdown.md`) so another visible session knows which rules were applied.
5. If a repo rule conflicts with the cross-repo plan, stop and surface the conflict before implementation.

For example, a service repo might have `.agents/instructions/`. Work touching controllers, workspace services, schemas, unit tests, database tests, integration tests, or code generation should read the matching instruction files before deciding the implementation path.

## Checkout Command Rules

When a packet lists another repo, include concrete commands.

Use configured worktree root from `config.yaml: worktrees.root`. For feature work, prefer the `worktree-feature-create` skill so the cross-platform bundled script uses the same canonical Python implementation as the human `wt-feature` alias.

Cross-platform feature setup:

```bash
python3 <workbench-root>/.agents/skills/worktree-feature-create/scripts/wt_feature.py --repo <repo> <branch-name> <base-branch>
```

Windows Python launcher variant:

```bat
py -3 C:\worktrees\workbench\.agents\skills\worktree-feature-create\scripts\wt_feature.py --repo <repo> <branch-name> <base-branch>
```

For human terminal use, start from the target repo base directory and use `wt-feature` / `wt-review` so local worktree layout and config sync stay consistent.

macOS:

```bash
cd /path/to/worktrees/<repo>.git
wt-feature <branch-name> <base-branch>
wt-review <PR-or-branch>
```

Windows:

```bat
cd /d C:\worktrees\<repo>.git
wt-feature <branch-name> <base-branch>
wt-review <PR-or-branch>
```

If the shell functions or commands are not loaded in the current terminal, call the canonical Python script directly for feature work:

macOS:

```bash
python3 <workbench-root>/.agents/skills/worktree-feature-create/scripts/wt_feature.py --repo <repo> <branch-name> <base-branch>
```

Windows:

```bat
py -3 C:\worktrees\workbench\scripts\worktrees\wt_feature.py --repo <repo> <branch-name> <base-branch>
```

For review work, start from the target repo base directory and use the existing `wt-review` wrapper until review worktrees are also moved to the Python core.

If the command must be run from the target repo base directory, say so. If unsure whether a PR exists in that repo, give a feature inspection worktree command from `main` or `develop` instead of inventing a PR. Do not do code-changing work directly in `main`, `develop`, or the repo base directory unless the user explicitly asks for it.

## Mode Details

Read only the relevant section from [the mode reference](references/modes.md) after selecting a mode. This keeps `SKILL.md` small and follows AgentSkills progressive disclosure.

For any mode that creates a plan, PR breakdown, validation artifact, context packet, reviewer packet, review findings, prompt packet, lifecycle state, activity log, or PR writeup, also read `context/standards/html-plan-standard.md`. The standard inverts the legacy HTML-first default: text-heavy strategic content is Markdown-first (`.md`) so agents can read it cheaply and so human reviewers get the same content without paying CSS/SVG parsing cost. HTML companions are added only when the artifact has substantial visual content (architecture diagrams, mockups, side-by-side semantic-color matrices); reviewer packets are the most common HTML candidate when they carry visual review flow.

For `full`, `watch`, `review-packet`, `review`, and `pair` reviewer prompts, also read [engineering invariants](references/engineering-invariants.md). These invariants are mandatory review criteria. Repo-specific invariant docs under the target repo or `context/agent-flow/invariants.md` / legacy `context/agent-flow/invariants.md` extend them. Reviewer prompts must require both content/intent review and engineering-invariant review.

For `full`, `plan`, `watch`, `review-packet`, `review`, `pair`, and `publish` modes that create or evaluate validation, also read [validation practices](references/validation-practices.md).

Mode sections in `references/modes.md`:

- `full`: run the full gated lifecycle from context to plan review, implementation review, final packet, and PR draft.
- `watch`: advance the visible terminal-pair state machine using `pipeline.md`.
- `capture`: preserve chat-first context into `chat-capture.md`, then create HTML packets when needed.
- `context`: create `context-packet.md` from Jira, plan, chat capture, or natural language.
- `review-packet`: create portable `reviewer-packet.md` (or `.html` when the packet has visual review flow) for another engineer and their agent.
- `plan`: interview the user, create or link `plan.md`, and co-create `validation-plan.md`.
- `jira`: draft/create/update Jira by default unless opted out; external Jira writes only after explicit approval.
- `review`: review from packet without editing files.
- `pair`: prepare Claude/Codex prompts against shared Workbench artifacts.
- `publish`: create Jira/PR-safe packet summaries after approval.
- `apply`: apply accepted external findings only when explicitly requested.

## Status Mode

Summarize:

- work item path,
- latest artifacts,
- linked Jira/PR,
- required repos and whether they are present locally,
- open questions,
- recommended next action.

Keep this under 20 lines.

## Portability Rules

A packet is good only if another engineer can use it cold.

Every packet should:

- use local Workbench paths when the reviewer has this Workbench,
- include Jira/PR-safe summaries when the reviewer may not have this Workbench,
- convert private chat context into durable summarized decisions, assumptions, and scope,
- name exact repo paths or checkout commands,
- name exact files to read,
- distinguish confirmed facts from assumptions,
- include the agent prompt to use,
- link to Jira/Confluence/PRs when available,
- preserve enough context for a different local agent.

## Asking Clarifying Questions

The interactive intake gate comes first when entrypoint or mode is missing. After that, ask only when the answer changes the artifact. Prefer these questions:

1. "Should this be anchored on a chat capture, plan, Jira ticket, PR, or a short problem statement?"
2. "Is this for author implementation, reviewer handoff, or actual review?"
3. "Which product surface or service boundary matters most?"

Do not ask the user to enumerate every repo. Infer likely repos first, then let the user correct the packet.

## Closeout

End with:

- artifact path(s) written,
- repos the packet says to inspect,
- missing information or assumptions,
- next command/prompt for the user or reviewer.

Mention validation if any commands were run. If no live Jira/PR access was available, say the packet is based on local/context-only evidence.
