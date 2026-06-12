# Validation Practices

Use this reference when `agent-flow` creates or reviews `planning-interview.md`, `plan.html`, `validation-plan.html`, `validation-evidence.html`, `reviewer-packet.html`, or PR handoff text.

## Research Basis

- ISTQB Foundation Level testing principles: exhaustive testing is not feasible, so validation should be risk-based and prioritized; testing should start early in the lifecycle; repeated tests need to evolve to keep finding defects.
- Google Testing Blog testing-pyramid guidance: prefer many fast, focused unit tests, meaningful integration tests for boundaries, and a small number of end-to-end tests for critical workflows. Avoid replacing integration proof with slow, brittle E2E checks.
- Playwright best practices: UI tests should verify user-visible behavior, stay isolated, control test data, and avoid relying on implementation details or uncontrolled third-party systems.
- Docker Compose and Testcontainers docs: when behavior depends on services, databases, queues, or other infrastructure, containerized dependencies are valid integration/smoke-test tools.
- Pact contract-testing docs: for service-to-service boundaries, validate concrete consumer/provider expectations instead of relying only on broad deployed-world E2E checks.

## Validation Planning Rule

Validation is planned during the user interview. The agent proposes evidence, the user confirms the validation bar, and implementation follows that plan.

Use the tool-native interview primitive:

- Claude Code: use `AskUserQuestion`.
- Codex: use `request_user_input` when available.
- If the tool is unavailable, ask the same focused question in chat and wait.

Do not finalize `plan.html`, `validation-plan.html`, or `pr-breakdown.html` until the validation bar is confirmed or explicitly delegated by the user.

## Recommended Validation Layers

Choose the smallest set of layers that proves the behavior and risk. Prefer targeted proof over broad suites, but do not stop at unit tests when the behavior crosses a runtime boundary.

1. Static and local checks:
   - formatting, type checks, lint checks, schema validation, generated-client diffs.
2. Unit or component tests:
   - pure logic, branching, edge cases, failure handling, serialization/deserialization.
3. API and data validation:
   - explicit HTTP/gRPC/tool calls to the changed runtime path,
   - read data needed to prove preconditions and postconditions,
   - verify response body, status, side effects, persistence, authorization, and telemetry when relevant.
4. Contract checks:
   - consumer/provider expectations, OpenAPI/schema compatibility, event payload shape, queue/message contracts.
5. Containerized integration or smoke validation:
   - Docker Compose or Testcontainers when the scenario depends on a database, queue, cache, service dependency, or realistic local stack.
6. UI/browser validation:
   - browser/manual walkthrough checks for user-visible behavior, with controlled data and stable selectors.
7. Manual verification:
   - only for cases that cannot be reliably automated in the current environment; record exact steps, inputs, expected result, and observed result.

## Browser Validation Tool Order

When UI or browser behavior is part of the validation plan, use the best available interactive/browser tool in this order:

1. Codex environment:
   - use the `browser-use` / Browser skill when available,
   - manually walk through the scenario in the in-app browser,
   - record URL, viewport when relevant, exact steps, expected result, observed result, and any console/network evidence available.
2. Claude environment:
   - use the Claude-in-Chrome / Chrome MCP path when available,
   - manually walk through the scenario with the user's logged-in Chrome context when auth or profile state matters,
   - record URL, exact steps, expected result, observed result, and screenshots/logs when available.
3. Playwright MCP:
   - use Playwright MCP when available and the scenario can be automated or semi-automated through the browser.
4. Playwright CLI:
   - use repo-local Playwright tests, `npx playwright`, `pnpm exec playwright`, or equivalent CLI when MCP/browser skills are unavailable.
5. No browser automation available:
   - do not claim browser validation,
   - tell the user which browser path was unavailable,
   - provide exact manual steps and recommend using browser-use, Claude-in-Chrome, Playwright MCP, or Playwright CLI.

Browser validation should exercise the user-visible behavior, not private implementation details. Prefer stable user-facing selectors, controlled test data, and isolated scenarios. For non-trivial UI changes, cover the happy path and at least one edge or failure path.

## Scenario Coverage

Every non-trivial validation plan should list:

- happy path,
- at least one high-value edge case,
- at least one failure or negative case when applicable,
- authorization/tenancy/privacy case when sensitive data or permissions are involved,
- empty/missing data behavior,
- timeout/retry/partial-failure behavior when service calls are involved,
- backward compatibility or migration behavior when contracts, schemas, or stored data change.

## API And Runtime Proof

When the system exposes an API, MCP tool, gRPC method, CLI, event consumer, or web endpoint, prefer explicit runtime calls over indirect inference.

Good validation evidence includes:

- command or script,
- working directory,
- environment and base URL,
- request payload or fixture name,
- response status and important body fields,
- persisted data or emitted event proof when relevant,
- logs/traces/metrics queried when observability is part of the change.

Do not claim runtime validation from code inspection alone.

## Containerized Proof

Use Docker Compose or Testcontainers when local runtime proof needs dependencies.

Record:

- compose file or testcontainer fixture,
- services started,
- health checks or readiness checks,
- seed data,
- scenario command,
- logs inspected,
- teardown command or automatic cleanup.

If containers cannot run, record the missing prerequisite and the exact command a developer should run later.

## Validation Evidence Status

Use one of:

- `passed`: required evidence ran and matched expectations.
- `failed`: required evidence ran and did not match expectations.
- `blocked`: evidence could not run because a prerequisite is missing.
- `unverified`: user explicitly accepted missing proof for now.
- `pending`: not attempted yet.

Reviewers must treat missing, irrelevant, hand-waved, or failed validation as a finding. Mark it blocker when the change cannot be trusted without that proof.
