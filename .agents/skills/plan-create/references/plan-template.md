# HTML Plan Template Notes

`plan-create` creates HTML-first plans.

Primary artifact:
- `context/plans/active/<plan-name>/plan.html`

Compatibility artifact:
- `context/plans/active/<plan-name>/plan.md`
- Keep this to a short synopsis and link to `plan.html`.

Before generating `plan.html`, read:
- `context/standards/html-plan-standard.md`

Use this high-level structure for implementation plans and PR breakdowns:

1. Hero/summary band:
   - feature name,
   - plan version/date/depth,
   - target repo(s),
   - Jira/PR/plan anchors,
   - confidence and primary risk.
2. Decisions and success:
   - success criteria,
   - decisions locked in,
   - explicit non-goals.
3. PR breakdown timeline:
   - one milestone per PR slice,
   - scope,
   - target repo/files,
   - dependencies,
   - validation,
   - exit criteria.
4. Flow diagram:
   - inline SVG data flow, service flow, UI flow, or deployment flow.
5. Risk and operations:
   - risks/mitigations,
   - scalability plan,
   - exception-handling plan,
   - observability/alerting/dashboard plan,
   - security/privacy/auth/tenancy notes.
6. Review and handoff:
   - files to inspect first,
   - reviewer focus,
   - open questions,
   - copyable implementation or review prompt when useful.

The full plan content belongs in `plan.html`, not `plan.md`.
