# Phase: CREATE

Read and apply the full methodology from `.agents/skills/plan-create/SKILL.md`.

## Forge-Specific Modifications

1. **Skip redundant interview questions** — INTAKE and REFINE already answered most of plan-create's standard interview. Do NOT re-ask: what are you building, who is it for, what are the constraints, what technologies are involved. Only ask about genuinely new ambiguities.
2. **Pre-creation deep interview** — before generating, run the CREATE interview (2 rounds via AskUserQuestion) as defined in the forge SKILL.md. This validates that the user's thinking hasn't drifted after research/challenge/refine.
3. **Include all REFINE decisions** — every decision from REFINE + CREATE interview goes in the "Decisions Locked In" table. No decision should be missing.
4. **Include all risks from analysis.md** — every risk from the challenge phase appears in the risk assessment section.
5. **Consistency check** — after generating, verify: all REFINE decisions appear, all risks appear, no stale assumptions from earlier iterations remain. Flag any inconsistencies.
6. **Plan versioning** — track version number reflecting iteration count. If this is plan v3 (after 2 loop-backs), label it v3.
7. **Output location** — write `plan.md` + `handoff.md` to `context/plans/active/<plan-name>/`.
8. **Handoff audience** — tailor handoff.md detail level based on CREATE interview Q6 (solo, pair, or handoff to someone else).
9. **PRD integration** — if `prd.md` exists in the plan directory (from standalone `/prd-create` or forge-integrated generation):
   - Reference it in plan.md's References section
   - Reference it in handoff.md's Strategic Context section
   - Pull user stories, acceptance criteria, and design specs from the PRD rather than re-deriving them
   - The full output is the triple: `prd.md` + `plan.md` + `handoff.md`
10. **PRD generation option** — if no `prd.md` exists and the user requests one in CREATE Round 2 Q8, run `/prd-create` in forge-integrated mode before generating plan.md. The prd-create skill will detect forge artifacts (state.md) and run an abbreviated interview focused on product-definition gaps.
