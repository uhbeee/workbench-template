---
name: brainstorm
description: "Freeform ideation and structured shortlisting. Generates 8-10 approaches including wild cards, then converges on 2-4 viable options with tradeoffs. Use before /forge or standalone for any creative exploration."
argument-hint: <topic or problem statement>
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# `/brainstorm` — Divergent Ideation + Convergent Shortlisting

Generate approaches to a problem before committing to a direction. Two modes: divergent (quantity, wild ideas) then convergent (evaluate, shortlist).

Also invoked as optional Phase 0 inside `/forge`.

## Usage

```
/brainstorm <topic>                    # Standalone brainstorm
/brainstorm "observability for MCP"    # With quoted description
```

## Process

### Step 1: Understand the Problem

If the user's prompt is vague, use `AskUserQuestion` to clarify:
- What problem are you trying to solve?
- Any constraints or non-negotiables?
- What have you already ruled out?

If the prompt is clear, proceed directly.

### Step 2: Freeform Ideation (Divergent)

Generate **8-10 approaches** to the problem:
- Include the obvious solutions (the user expects these)
- Include at least **2 "wild card" ideas** that challenge assumptions about the problem itself
- No filtering, no judgment — quantity over quality
- Each approach: 1-line description + 1-line "why this might work"

Present as a numbered list. Do NOT evaluate yet.

### Step 3: Structured Shortlist (Convergent)

Use `AskUserQuestion` to understand evaluation criteria if not already known:
- "What matters most — speed to ship, long-term maintainability, simplicity, or something else?"

Then evaluate all approaches against known constraints and criteria. Produce a **shortlist of 2-4 viable approaches**:

For each shortlisted approach:
- **Relative complexity**: low / medium / high (NOT effort estimates — those come later with full context)
- **Risk level**: low / medium / high
- **Key assumption**: what must be true for this approach to work
- **Tradeoff**: what you give up by choosing this

### Step 4: User Selection

Use `AskUserQuestion`:
- "Which approach(es) do you want to explore further?"
- Options: each shortlisted approach + "Combine elements from multiple" + "None — brainstorm more"

If "brainstorm more" → loop back to Step 2 with refined constraints (max 2 loops).

### Step 5: Output

**Standalone mode**: Save to `context/notes/brainstorm/YYYY-MM-DD-slug.md` with:
- The full ideation list
- The shortlist with evaluations
- The selected approach(es)
- Suggest: "Run `/forge <name>` to plan this."

**Inside `/forge`**: Write to state.md:
- Selected approach description
- What's known (from brainstorm discussion)
- What's NOT yet known (for INTAKE to focus on)
- Rejected approaches and why (prevents re-research)

## Key Principles

1. **Diverge before converging.** Don't skip the wild ideas phase. The best solutions often come from combining unexpected approaches.
2. **No effort estimates.** Use relative complexity. Effort estimation requires constraints, team size, and timeline — brainstorm doesn't have those yet.
3. **Challenge the problem, not just the solution.** At least 2 wild cards should question whether the problem as stated is the right problem to solve.
4. **User picks, system doesn't.** Present options with tradeoffs. Don't recommend. The user's intuition about what fits their context is more valuable than algorithmic ranking at this stage.
5. **Short and fast.** Brainstorm should take 5-10 minutes, not 30. If it's taking longer, the problem needs research, not brainstorming.
