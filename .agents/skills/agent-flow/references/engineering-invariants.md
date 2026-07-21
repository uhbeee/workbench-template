# Engineering Invariants

These invariants apply across most codebases. They are reviewer-enforced constraints, not style preferences. Repo-specific `AGENTS.md`, `WORKFLOW.md`, `knowledge-base/invariants/*.md`, `docs/invariants/*.md`, or `context/agent-flow/invariants.md` may add stricter rules; stricter local rules win.

## Research Basis

These rules are grounded in broadly accepted engineering practice:

- Google Engineering Practices frames code review around improving long-term code health, maintainability, readability, tests, documentation, consistency, design, and functionality.
- Google SRE and AWS Well-Architected treat monitoring, alerting, dashboards, runbooks, owner clarity, and root-cause analysis as part of operating production software, not optional polish.
- AWS and Azure reliability guidance require capacity limits, quotas, load/fault testing, bounded retries, backoff, circuit breakers, and graceful degradation for scalable distributed systems.
- OWASP logging guidance requires application-level security logs while keeping secrets, tokens, credentials, and sensitive personal data out of logs and telemetry.
- Microsoft API guidance treats structured error responses, stable error codes, status semantics, traceability, throttling signals, and overload signals as API contract concerns.
- Fowler's refactoring/design-stamina work supports the economic reason for keeping code simple, cohesive, and easy to change over time.

## Reviewer Enforcement

Every plan review, implementation review, PR review, and external review must:

1. Read this file.
2. Re-enumerate and read any repo or Workbench invariant docs that exist.
3. Treat invariant drift as a finding, even when the code appears to work.
4. Mark findings with `Invariant: <name/path/section>` and count invariant findings separately in the review summary.
5. Prefer blocker or should-fix severity for invariant violations. Use nit only when the violation is purely local and low-risk.

## Universal Invariants

### 1. Reuse Before New Implementation

Before building a new implementation, check whether a similar implementation, helper, component, service, endpoint, job, dashboard, alert, or pattern already exists.

Do not silently create parallel implementations. If a separate implementation is intentional, document why it should stay separate and what tradeoff is being accepted.

Review question: why is this separate instead of reusing, extending, or merging with the existing implementation?

### 2. Behavior And Pattern Deviations Must Be Explicit

Do not silently change behavior or introduce a different implementation pattern from the surrounding code.

Examples:
- moving work from backend to frontend,
- changing sync to async semantics,
- changing retry or error handling behavior,
- changing data ownership or source of truth,
- introducing a new state, data-fetching, rendering, routing, or service pattern.

Review question: what behavior or pattern changed, why is that change intentional, and was the user/team told?

### 3. Root Cause Before Workaround

Do not add a workaround before understanding the root cause well enough to know whether the fault is internal or external.

If the root cause is internal, fix the root cause. If the root cause is external, the workaround must be explicit, narrow, tested, and observable.

Review question: what is the confirmed root cause, and why is this not masking our own bug?

### 4. Source Of Truth Stays Server-Side For Data Semantics

Filtering, authorization, tenancy, ranking, persistence semantics, and other source-of-truth decisions should live in the backend or owning service, not in a presentation layer.

Client-side filtering or transformation is acceptable only for narrow presentation concerns that do not replace the authoritative data path.

Review question: is the UI rendering authoritative data, or is it quietly computing product semantics locally?

### 5. Tests Ship With Behavior Changes

Every behavior change must include or update tests in the same change. Running existing tests is not enough if no test exercises the changed behavior.

Do not delete, weaken, skip, or loosen tests to make a change pass unless the new intended behavior is covered with equal or better rigor and the reason is explicit.

Review question: which test would fail if this behavior regressed?

### 6. Documentation And Knowledge Base Stay In Sync

When code changes a documented flow, endpoint, model, operational process, service contract, or user-visible behavior, update the corresponding documentation in the same change.

Create new docs only when the change genuinely does not fit an existing documented area.

Review question: would another engineer looking at the docs understand the behavior that now exists in code?

### 7. Observability Is Part Of The Feature

New or changed critical paths must be diagnosable in production. This usually means structured logs, metrics, traces, correlation identifiers, and useful error surfaces at the owning service boundary.

Do not log secrets, tokens, sensitive personal data, or high-cardinality payloads. Observability must make failures understandable without creating privacy or cost problems.

Review questions:
- How would on-call know this is failing?
- What signal identifies the affected tenant/user/job/request without exposing sensitive data?
- Are errors and retries visible at the right boundary?

### 8. Alerting And Dashboards For Operable Paths

Async jobs, integrations, queues, scheduled tasks, high-volume endpoints, billing/credit paths, auth flows, data pipelines, and other operable systems need an alerting/dashboard story when the change creates or changes a failure mode.

Not every small change needs a new alert. But every production-critical behavior needs either an existing signal that covers it or an explicit note that no new alert/dashboard is needed and why.

Review questions:
- Which existing dashboard or alert covers this?
- If the job stalls, errors spike, latency regresses, or data stops flowing, who notices?
- Is the runbook or owner obvious?

### 9. Maintainable Structure And Readability

Code should follow local structure, naming, and abstraction patterns. Prefer small cohesive units, clear ownership boundaries, explicit data shapes, and readable control flow.

Do not introduce unnecessary abstraction, broad refactors, dead code, hidden coupling, duplicated business logic, or clever code that future maintainers cannot inspect quickly.

Review questions:
- Does this fit the surrounding module structure?
- Is the responsibility boundary obvious?
- Could the next engineer safely change this without reading unrelated systems?

### 10. Security, Privacy, Auth, And Tenancy Are Non-Negotiable

Any new endpoint, service method, data access path, log field, integration call, or background job must preserve authorization, tenancy isolation, privacy, and secret-handling guarantees.

Review questions:
- What prevents cross-tenant or unauthorized access?
- Are secrets and sensitive data kept out of logs, metrics, traces, and PR artifacts?
- Are external inputs validated at the trust boundary?

### 11. Operational Cost And Performance Must Be Bounded

Do not introduce unbounded fan-out, unindexed queries, N+1 hot paths, blocking I/O in request paths, uncontrolled retries, unbounded payload growth, or high-cardinality telemetry.

Review question: what bounds cost, latency, memory, retry volume, and data size under realistic production load?

### 12. Scalability Must Be Planned Explicitly

Changes that touch high-volume paths, async processing, queues, integrations, search, AI/model calls, data pipelines, storage growth, bulk operations, or user-facing latency must include an explicit scalability plan.

The plan should name the expected scale assumptions, the bounding strategy, and the verification method. Depending on the change, that may include pagination, batching, backpressure, idempotency, rate limits, retry budgets, queue depth limits, concurrency controls, indexes, cache strategy, payload limits, timeout budgets, cost controls, or load/perf probes.

It is acceptable to say "no scalability impact" only when the reason is concrete.

Review questions:
- What grows with users, tenants, requests, records, candidates, jobs, messages, or model calls?
- What bounds that growth?
- How was the bound verified or made observable?
- What happens when the upstream dependency slows down, rate-limits, or fails?

### 13. Exception Handling Must Preserve Semantics And Debuggability

Exception handling should make failures safer and clearer without swallowing defects or hiding operational signals.

Do not add broad `catch Exception`, empty catches, generic fallback behavior, or log-and-continue paths unless the failure mode is understood and the fallback is intentionally safe. Exceptions should be translated at the right boundary into typed errors, user-safe messages, retry/dead-letter behavior, or explicit failure states.

Good exception handling usually includes:
- catching the narrowest meaningful exception,
- preserving cause/context for debugging,
- avoiding secrets or sensitive data in logs/errors,
- distinguishing retryable from non-retryable failures,
- using idempotency or compensation when partial writes are possible,
- surfacing structured telemetry for failure rate and affected entity,
- tests for the failure path, not only the happy path.

Review questions:
- Is this catch block too broad?
- Does the caller receive the right semantic error?
- Are partial writes, retries, and duplicate processing handled safely?
- Would on-call have enough context to debug this without sensitive data exposure?
- Is there a test that proves the intended failure behavior?
