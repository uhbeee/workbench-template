# Phase: HANDOFF

Read and apply the full methodology from `.agents/skills/plan-resume/SKILL.md`.

## Forge-Specific Modifications

1. **Two modes based on state**:
   - If `progress.md` exists → this is a resume. Generate a continuation prompt using plan-resume methodology.
   - If no `progress.md` → this is the initial handoff. Present `handoff.md` as the implementation prompt.
2. **Update state.md** — mark phase as `ready` after handoff is complete.
3. **Include forge context** — the handoff/resume prompt should reference the plan's iteration history and key decisions, not just the final plan.md. This helps the implementer understand WHY decisions were made.
4. **Suggest target repo** — if INTAKE captured a target repo, suggest: "Copy handoff.md to [repo] and start a new Claude Code session there."
