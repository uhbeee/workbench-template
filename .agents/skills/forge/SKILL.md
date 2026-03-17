---
name: forge
description: "Unified feature planning pipeline. Chains brainstorm, intake, research, challenge, refinement, plan creation, external judging, and handoff. Replaces manual /plan-feature → /research → /sounding-board → /plan-create → /plan-resume orchestration."
argument-hint: <plan-name> [description] [--depth=quick|standard|deep] [--skip-to=research|challenge|refine|create|judge|resume] [--judge=codex|gemini|claude|all] [--no-chain] [save|resume|archive]
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# `/forge` — Unified Feature Planning Pipeline

One command, full pipeline. Chains brainstorm → intake → research → challenge → refine → create → judge → handoff with user checkpoints between phases. Supports iteration loops, external LLM judges, and anti-compaction handoff.

## Interaction Model

**Always use `AskUserQuestion`** when you need user input — phase confirmations, intake questions, refinement decisions, scope calibration, checkpoint approvals. Never guess at the user's intent. Present clear options with descriptions. Use multi-select when choices aren't mutually exclusive. Use previews for concrete artifacts the user needs to compare.

**Replaces**: The manual sequence of `/plan-feature` → `/research` → `/sounding-board` → "use AskUserQuestion to update" → `/plan-create` → `/plan-resume`.

## Usage

```
/forge                                    # List all active plans
/forge <name>                             # Start or resume (auto-detect depth)
/forge <name> <description>               # Start new plan with description
/forge <name> --depth=quick               # Light: intake→sanity check→create
/forge <name> --depth=deep                # Full pipeline + dual judge
/forge <name> --skip-to=create            # Jump to plan creation
/forge <name> --judge                     # Force judge on standard depth
/forge <name> --no-chain                  # Run current phase only, save state, exit
/forge <name> save                        # Trigger anti-compaction handoff
/forge <name> resume                      # Generate resume prompt for target repo
/forge <name> archive                     # Archive completed/abandoned plan
```

## Core Model: Auto-Advance with Checkpoints

```
[BRAINSTORM] → INTAKE → RESEARCH → CHALLENGE → REFINE → CREATE → JUDGE → HANDOFF
  (optional)     │          │          │          │         │        │        │
  ask(shortlist) ask(2rnd)  ask(1rnd)  ask(summary) ask(per  ask(2rnd) ask(1rnd) done
                                                   challenge)
```

Each phase completes and proposes the next. User confirms before advancing.
At any checkpoint, the user can: **continue**, **iterate** (re-run phase), **skip**, or **stop** (save and exit).

### Universal Loop-Back Mechanism

Any phase can route to any earlier phase. Max **3 total loop-backs** across the pipeline.

| From | To | Trigger |
|------|----|---------|
| REFINE | RESEARCH | Evidence gaps from sounding board |
| REFINE | CHALLENGE | User wants re-validation after significant changes |
| CREATE | REFINE | Scope/priority shift during pre-creation interview |
| CREATE | RESEARCH | Missing context discovered during interview |
| JUDGE | CHALLENGE | Judge flags unaddressed risks |
| JUDGE | RESEARCH | Judge flags contradictions needing new evidence |

When a loop-back occurs:
1. Present the reason and estimated context cost: "This loop-back re-runs [N] phases. At [X]% context, [risk assessment]. Proceed?"
2. User confirms (or overrides: "no, proceed anyway")
3. Re-run all intermediate phases between target and source. Each checks artifact staleness — quick validation if consistent, full re-run if stale.
4. Iteration log records the transition.

**Three-layer loop prevention**:
1. **Hard cap**: Max 3 total loop-backs
2. **Quality-based convergence**: If loop-back #2+ on the same topic and gap hasn't narrowed → recommend proceeding with caveats
3. **Token budget**: If context usage >70% (via StatusLine) → recommend reducing rather than looping

## Process

### Step 0: Load State

1. Read `~/.claude/workbench-root` for workbench path.
2. Read `config.yaml` for org context.
3. If no plan name → list all active plans (scan `context/plans/active/*/state.md`) and exit.
4. If `archive` argument → move to `context/plans/archive/` and exit.
5. If `save` argument → run anti-compaction capture (see Anti-Compaction section) and exit.
6. If `resume` argument → read plan artifacts and generate resume prompt (read `phases/handoff.md`) and exit.
7. Read `state.md` + all existing artifacts for this plan.
   - Check for `prd.md` in the plan directory. If it exists, note `has_prd = true` in context. This PRD was created by `/prd-create` (either standalone or in a prior session) and contains product definition that INTAKE and CREATE should reference rather than re-derive.
8. **Migrate old-format state.md** — if state.md exists but is missing expected fields (Depth, User Context, Brainstorm), migrate in place:
   - Add `Depth: standard` if missing
   - Add empty `User Context` section if missing
   - Map old phase names: `plan` → `create`, `analysis` → `challenge`
   - Map old column names in Decisions table if needed
   - Inform user: "Migrated state.md to /forge format."
9. If `--skip-to` set → override current phase.
10. If resuming an existing plan → present brief status and continue from current phase.

### Step 1: BRAINSTORM (Optional)

**Mode: Divergent Explorer** — Generate freely, no filtering, wild cards welcome.

**Goal**: Divergent thinking before committing to an approach.

**When to offer**:
- Quick depth: skip
- Standard depth: "Do you already know what you want to build, or want to brainstorm approaches first?"
- Deep depth: "For a decision this significant, brainstorming approaches first is recommended. Want to explore options?"

**If user opts in**:

**Freeform ideation** (divergent):
- Generate 8-10 approaches, including 2+ "wild card" ideas that challenge assumptions about the problem itself
- No filtering — quantity over quality
- Present as a numbered list with 1-line descriptions

**Structured shortlist** (convergent) — use `AskUserQuestion`:
- Evaluate approaches against known constraints
- Shortlist 2-4 viable approaches
- For each: relative complexity (low/medium/high), risk level, key assumption
- Ask: "Which approach(es) do you want to explore further?"

**Output**: Write to state.md:
- Selected approach description
- What's known (from brainstorm discussion)
- What's NOT yet known (for INTAKE to focus on)
- Rejected approaches and why (prevents re-researching)

**Checkpoint**: "Selected approach: [summary]. Moving to intake to gather details."

### Step 2: INTAKE (Deep Interview)

**Mode: Curious Interviewer** — Ask probing questions, surface implicit assumptions, one topic per question.

**Goal**: Deeply understand what the user is building, why, and what they already know. This is the **most important phase**.

**If brainstorm ran**: Read brainstorm output from state.md. Skip questions already answered (typically "What are you building?" and "What have you tried?"). Focus on what brainstorm didn't cover.

**If prd.md exists** (`has_prd = true`): Read the PRD's Overview, Problem Statement, Goals, User Stories, and Scope sections. Summarize: "From the PRD, I know: [summary]. I'll focus on engineering context the PRD doesn't cover." Skip questions already answered in the PRD (typically "What are you building?", "Who benefits?", "Success criteria", "Scope boundaries"). Focus INTAKE on: tech familiarity, implementation constraints, context pointers, and codebase-specific concerns not in the PRD.

**Round 1 — What and Why** (via `AskUserQuestion`, 3-4 questions, skip answered):
1. **What are you building?** (skip if brainstorm ran)
2. **Why now? What's the trigger?**
3. **Who benefits and how?**
4. **What does success look like?** — concrete outcomes

**Depth auto-detection** (after Round 1): Assess complexity, Type 1 vs Type 2, number of unknowns. Recommend depth: "This sounds like a [Type]. I'd recommend [depth]. Agree?" User confirms or overrides.

**Round 2 — Context and Constraints** (skip for quick depth):
5. **Tech familiarity** — rate 1-5 per key technology. Shapes all subsequent question framing.
6. **Context pointers** — Slack threads, Jira tickets, Confluence docs, codebase files
7. **Constraints** — timeline, team, patterns, immovables
8. **What have you already tried?** (skip if brainstorm ran)

After Round 2, refine depth recommendation if familiarity data shifts it.

**Adaptive behavior**:
- User's initial message answers questions → skip those
- Round 1 reveals simple task → suggest `--depth=quick`, skip Round 2
- User uncertain about the problem → add problem-framing question

**Output**: Populate state.md with intake data (decisions, constraints, expertise levels, success criteria).

**Checkpoint**: "Here's my understanding: [2-3 sentences]. Correct? Starting research next."

### Step 3: RESEARCH

**Mode: Evidence Gatherer** — Objective, source-cited, no editorializing. Present findings before asking decisions.

**Goal**: Build the evidence base, informed by INTAKE context.

Read and apply the full methodology from `.agents/skills/research/SKILL.md` with these forge-specific modifications (detailed in `phases/research.md`):
- Start with user's context pointers from INTAKE
- Depth set by forge depth profile
- Research scoped by INTAKE constraints (skip options user ruled out)

**Output**: Write `research.md`. Present **executive summary** (5-8 bullets) BEFORE asking any decisions.

**Checkpoint**: "Research complete. Key findings: [summary]. I'll stress-test this next. Want to research anything else first?"

### Step 3.5: SCOPE CALIBRATION (between RESEARCH and CHALLENGE)

**Mode: Strategic Advisor** — Present options with tradeoffs, respect the user's domain judgment.

**Goal**: Calibrate ambition level now that research has revealed the true scope.

**Skip for quick depth.**

After presenting the research executive summary and before moving to CHALLENGE, use `AskUserQuestion` to present:

"Research suggests this is a **[size/complexity assessment]** effort. Before I stress-test it, let's calibrate scope:

- **Expand**: [what expanding scope would look like — opportunities the research revealed that weren't in the original vision]
- **Hold**: [current scope is right — proceed as planned with research-informed adjustments]
- **Reduce**: [MVP cut — what to defer to get value faster, what the minimum viable version looks like]

Which direction?"

Record the decision in state.md under the Decisions table.
If user chooses **Expand** or **Reduce**, update the scope summary before proceeding to CHALLENGE. The challenge phase should evaluate the *calibrated* scope, not the original one.

**Checkpoint**: "Scope [expanded/held/reduced]. Proceeding to stress-test."

### Step 4: CHALLENGE

**Mode: Adversarial Critic** — Find holes, run pre-mortems, steelman then attack. No loyalty to prior phases.

**Goal**: Find the holes before reality does.

**Quick depth**: Lightweight 3-minute sanity check only — "2 things that could go wrong." No analysis.md, no full sounding-board. Present inline and move to CREATE.

**Standard/Deep depth**: Read and apply the full methodology from `.agents/skills/sounding-board/SKILL.md` with forge-specific modifications (detailed in `phases/challenge.md`):
- Read INTAKE expertise levels to calibrate intensity
- Output structured "evidence gaps" section for REFINE to parse
- Tag each challenge: **blocker** / **risk** / **note**

**Output**: Write `analysis.md`. Present findings grouped by severity.

**Checkpoint**: "Found [N] challenges: [X blockers, Y risks, Z notes]. [1-2 lines per challenge]. Ready to resolve these one by one?"

### Step 5: REFINE (The Key Innovation)

**Mode: Collaborative Resolver** — One issue at a time, present options, respect user domain knowledge.

**Goal**: Resolve every challenge one at a time with user input. This phase did not exist in the old pipeline.

**Skip for quick depth.**

1. Parse `analysis.md` for challenges, sorted by severity (blockers first).

2. **For each challenge** — use `AskUserQuestion`:
   - The concern (1-2 sentences, plain language)
   - Sounding board's recommended mitigation
   - Options: (a) accept (b) reject — explain why (c) modify (d) need more research
   - **Unfamiliar tech** (from INTAKE): provide recommendation, frame as "accept or push back"
   - **Familiar tech**: present tradeoffs, open-ended

3. Handle responses:
   - **Accept** → record decision, next challenge
   - **Reject** → record reasoning. Flag cascades: "This also affects X and Y. Revisit?"
   - **Modify** → record modification, update affected artifacts
   - **Research more** → loop back to RESEARCH (counts toward loop-back cap)

4. **Solicit domain challenges**: "Based on your experience, does anything feel wrong?"

5. **Present iteration diff**: "Here's what changed this round: [list]"

6. **Offer re-challenge**: "Stress-test the updated approach, or move to plan creation?"
   - Yes → loop to CHALLENGE (max 3 iterations)
   - No → advance to CREATE

**Checkpoint**: "All challenges resolved. [N] decisions, [M] changes. Ready for plan creation?"

### Step 6: CREATE (Deep Interview)

**Mode: Precise Architect** — Structured, complete, no ambiguity. Every section must be actionable.

**Goal**: Produce plan.md + handoff.md that reflect what the user actually wants after their thinking has evolved.

**Round 1 — Validate evolved understanding** (via `AskUserQuestion`, 3-4 questions):
1. **Scope check**: "In scope: [list]. Out of scope: [list]. Match your thinking?"
2. **Priority ordering**: "Items in priority order: [list]. Reorder?"
3. **Decision review**: "Top [3] impact decisions from refinement. Still confident?"
4. **Constraints evolved?**: "You said [constraint]. After research/tradeoffs, changed?"

**Round 2 — Plan shape** (2-3 questions, adapted):
5. **Work breakdown granularity**: large feature PRs vs small incremental?
6. **Handoff audience**: you solo, pair, or handing off?
7. **The ONE thing this plan must get right?** — becomes the plan's north star
8. **PRD option** (if `has_prd = false`): "This feature is [internal/external/customer-visible]. Need a formal PRD alongside the engineering plan?" If yes → run `/prd-create` in forge-integrated mode before generating plan.md. If `has_prd = true` → skip this question, reference existing prd.md in plan.md and handoff.md.

**Adaptive**: If scope/priorities shifted significantly in Round 1 → offer loop-back to CHALLENGE. If nothing changed → condense to 1 round.

**Generate**: Read and apply methodology from `.agents/skills/plan-create/SKILL.md` with forge-specific modifications (detailed in `phases/create.md`):
- Skip redundant interview questions (INTAKE + REFINE already answered)
- Include all REFINE + CREATE decisions in "Decisions Locked In" table
- Include all risks from analysis.md
- Consistency check: no stale assumptions
- Track plan version

**Output**: Write `plan.md` + `handoff.md`. If PRD was generated (or already existed), the plan directory now contains the full triple: `prd.md` + `plan.md` + `handoff.md`. Reference prd.md in both plan.md (under References) and handoff.md (under Strategic Context).

**Checkpoint**: "Plan created (v[N]). Review plan.md and handoff.md. Ready for judging?"

### Step 7: JUDGE (External LLM)

**Mode: Independent Evaluator** — No loyalty to prior phases, fresh assessment. Find what's wrong.

**Goal**: Cross-model second opinion.

**Quick depth**: Skip.
**Standard depth**: Claude-as-judge only (via Agent tool with adversarial prompt).
**Deep depth**: Both Codex CLI + Gemini CLI, with Claude fallback.

**Judge cascade** (try in order):
1. Codex CLI + Gemini CLI (both) → synthesize agreements/disagreements
2. If one fails → other + Claude fallback
3. If both fail → Claude-as-judge via Agent tool
4. User can force: `--judge=codex|gemini|claude|all`

Execute via bash wrapper scripts (`scripts/judge-codex.sh`, `scripts/judge-gemini.sh`) which handle retry, timeout, JSON parsing, and graceful degradation.

**Judge prompt** (`prompts/judge-review.md`) evaluates:
1. Does the plan address all identified risks?
2. Contradictions between research and plan?
3. What's missing?
4. Scope realistic for constraints?
5. What would you push back on?

**Present**: Synthesize judge responses. Agreements = strong signal. Disagreements = worth discussing.

**Checkpoint**: "Judges reviewed. [Summary]. Address any of these, or finalize?"

### Step 8: HANDOFF

**Mode: Technical Writer** — Clear enough for someone with zero context to execute autonomously.

**Goal**: Produce continuation prompt for target repo.

Read and apply methodology from `.agents/skills/plan-resume/SKILL.md` with forge-specific modifications (detailed in `phases/handoff.md`).

- If `progress.md` exists → generate resume prompt
- If no `progress.md` → present handoff.md as initial implementation prompt

Update state.md to `ready`.

**Generate progress.md**: Alongside handoff.md, generate an initial `progress.md` in the plan directory using this format:

```markdown
# Implementation Progress: <plan-name>

## Status
- Phase: implementing
- Current step: 0 of N
- Started: YYYY-MM-DD
- Last updated: YYYY-MM-DD HH:MM

## Branch State
- Branch: feature/<plan-name>
- Base: main
- Last commit: (not started)
- Ahead of base: 0 commits

## Steps
- [ ] Step 1: <description from plan>
  test: pending | files: | <est from plan> est
- [ ] Step 2: <description from plan>
  test: pending | files: | <est from plan> est
(... one checklist item per plan step ...)

## Boundary Checkpoints
| After Step | Boundary | Result | Issues |
|---|---|---|---|

## Decisions Made During Implementation
| Step | Decision | Why |
|---|---|---|

## Session Log
| Session | Steps Completed | Duration | Notes |
|---|---|---|---|
```

Pre-populate steps from the plan's work breakdown. Include time estimates if the plan has them. Leave test/files/actual fields empty. This progress.md will be used by `/implement` to track execution state.

## Anti-Compaction System

Three-layer protection for long sessions:

1. **StatusLine monitoring** — warns at 70%, alerts at 80% context usage
2. **PreCompact hook** — enhances existing `.agents/hooks/pre-compact-context.py` to capture forge state (phase, decisions, elicited user context, what to do next) into `continuation.md`
3. **Manual save** — `/forge <name> save` triggers capture at any time

continuation.md captures **elicited context** (expertise levels, constraints, preferences, rejected approaches, domain insights), not just state data.

## State Management

State.md owned exclusively by `/forge`. Format:

```markdown
# Plan State: <name>

## Current
- Phase: [brainstorm|intake|research|challenge|refine|create|judge|handoff|ready|done]
- Iteration: N
- Plan version: N
- Depth: [quick|standard|deep]
- Last updated: YYYY-MM-DD

## User Context (from INTAKE)
- Tech familiarity: { "tech": N, ... }
- Constraints: ...
- Success criteria: ...

## Brainstorm (if ran)
- Selected approach: ...
- Known: [what brainstorm established]
- Unknown: [what INTAKE needs to cover]
- Rejected: [approaches and why]

## Artifacts
| Artifact | Exists | Last Modified | Iteration |

## Decisions
| # | Topic | Decision | Rationale | Phase |

## Iteration Log
| # | From | To | Trigger | Notes |
```

## Depth Profiles

| Aspect | Quick | Standard | Deep |
|--------|-------|----------|------|
| BRAINSTORM | Skip | Optional | Recommended |
| INTAKE | 1 round (3 Qs) | 2 rounds (5-8 Qs) | 2 rounds + follow-ups |
| RESEARCH | Target repo + 2-3 web | Full internal + 5-8 web | Deep + 8-12 web |
| CHALLENGE | 3-min sanity check | One full pass | Two passes |
| REFINE | Skip | One round | Multiple rounds (up to 3) |
| JUDGE | Skip | Claude only | Codex + Gemini + Claude |
| CREATE | 1 round confirmation | 2 rounds deep interview | 2 rounds + consistency audit |
| Loop-backs | 0 | Up to 2 | Up to 3 |

**Auto-detection** (after INTAKE Round 1):
- **Quick**: Simple feature, familiar tech (4-5), clear reqs, Type 2
- **Standard**: Moderate complexity, some unfamiliar tech (2-3), cross-cutting
- **Deep**: Type 1 decision, multiple unknowns, unfamiliar tech (1-2), strategic bet

## Key Principles

1. **Ask before acting.** Use `AskUserQuestion` at every phase. Heaviest at INTAKE and CREATE.
2. **Present findings before asking decisions.** Show evidence first, then ask.
3. **One topic per question.** Don't overwhelm.
4. **Adapt to expertise.** Probe familiarity early. Recommend + "accept or push back" for unfamiliar tech. Tradeoffs for familiar tech.
5. **REFINE is first-class.** Not an afterthought.
6. **User domain insights are critical findings.** When the user challenges a recommendation, treat it as a sounding-board-level finding.
7. **Lazy phase loading.** Only read the current phase file + its referenced standalone skill.
8. **Track plan versions.** Show diffs between iterations.
9. **Estimate context cost before loop-backs.** Warn if a loop-back may trigger compaction.
