# Phase: CHALLENGE

Read and apply the full methodology from `.agents/skills/sounding-board/SKILL.md`.

## Forge-Specific Modifications

1. **Read INTAKE expertise levels** — calibrate challenge intensity based on tech familiarity from state.md. Don't present expert-level tradeoffs for technologies the user rated 1-2.
2. **Structured evidence gaps section** — at the end of the analysis, add a dedicated section listing evidence gaps that REFINE can parse:
   ```
   ## Evidence Gaps
   - [Gap 1]: [what's missing, could be resolved by targeted research]
   - [Gap 2]: ...
   ```
3. **Tag each challenge** — every challenge must be tagged: **blocker** (must address before plan), **risk** (should address), or **note** (nice to address). REFINE presents blockers first.
4. **Output location** — write `analysis.md` to `context/plans/active/<plan-name>/`.
5. **Quick depth** — do NOT run this phase. Instead, the forge orchestrator does a 3-minute inline sanity check ("2 things that could go wrong"). No analysis.md is written for quick depth.
6. **Deep depth** — run two passes. Second pass re-evaluates after any REFINE changes from the first pass.
