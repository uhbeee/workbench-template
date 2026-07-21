# HTML Plan Template Notes

Forge plans are HTML-first.

Primary artifact:
- `context/plans/active/<plan-name>/plan.html`

Compatibility artifact:
- `context/plans/active/<plan-name>/plan.md`
- Keep this to a short synopsis and link to `plan.html`.

Before generating `plan.html`, read:
- `context/standards/html-plan-standard.md`

For PR breakdowns, follow the implementation-plan pattern:
- top summary strip,
- milestone timeline,
- data/service flow SVG,
- optional mockups when UI behavior changes,
- key code or contract snippets for risky areas,
- risk and mitigation table,
- open questions with owners/deadlines,
- reviewer focus.

The full implementation plan content belongs in `plan.html`, not `plan.md`.
