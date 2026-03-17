# Phase: RESEARCH

Read and apply the full methodology from `.agents/skills/research/SKILL.md`.

## Forge-Specific Modifications

1. **Start with INTAKE pointers** — user's context pointers (Slack threads, Jira tickets, Confluence docs, codebase files) are in state.md under "User Context". Begin there, not with blind searching.
2. **Depth set by forge profile** — do not infer depth. Use the depth from state.md:
   - Quick: target repo + 2-3 web searches
   - Standard: full internal (Confluence, Jira, Slack) + 5-8 web
   - Deep: all internal + 8-12 web, multiple search angles
3. **Scoped by constraints** — skip options the user already ruled out in INTAKE. Don't research technologies the user said cannot change.
4. **Output location** — write `research.md` to `context/plans/active/<plan-name>/`, not `context/notes/research/`.
5. **Present findings before decisions** — show the executive summary BEFORE asking the user anything. This was the #1 friction point in prior sessions.
6. **If brainstorm ran** — research should focus on the selected approach, not all brainstormed alternatives. The rejected approaches are documented in state.md for reference.
