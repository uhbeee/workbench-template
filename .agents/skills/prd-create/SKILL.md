---
name: prd-create
description: Generate a Product Requirement Document (PRD) for a new or updated feature with HTML mockups. Works standalone or integrated into the forge pipeline. Use when creating PRDs, defining product requirements, scoping features, or when the user mentions PRD, product requirements, feature spec, or requirements document.
argument-hint: <plan-name> [--explore]
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# PRD Creator

Generate a comprehensive Product Requirement Document that eliminates ambiguity for design and engineering teams. The PRD captures what needs to be built and why, without prescribing how.

## Usage

```
/prd-create <name>              # Start or resume PRD creation
/prd-create <name> --explore    # Include codebase exploration of target repo
/prd-create <name> resume       # Resume after compaction
```

## Core Principles

- **Non-technical communication**: You are talking to a product owner. Never use technical terms (APIs, endpoints, models, components) in questions. Speak in plain language about user experiences and product behavior.
- **Eliminate ambiguity**: Every decision, edge case, and behavior should be explicitly documented.
- **High-level questions only**: Questions should not require codebase knowledge — ask about user goals, business rules, and product behavior.
- **Codebase-informed** (when `--explore` used): Read the codebase to understand current capabilities, but don't expose implementation details to the user.
- **Design & engineering audience**: The output is consumed by designers and engineers to build implementation plans.

## Context Awareness

This skill operates in two modes:

- **Standalone mode**: No forge artifacts exist. Runs full interview (Phases 1-7).
- **Forge-integrated mode**: `state.md` exists with forge phase data (INTAKE answers, research, challenge findings). Abbreviated interview — skips topics already captured in state.md User Context. References research.md and analysis.md findings.

Detection: Check `<workbench>/context/plans/active/<name>/state.md`. If it exists and has a `Phase:` field → forge-integrated mode. Otherwise → standalone mode.

---

## Phase 1: Gather Inputs

**Goal**: Collect all available context before exploring the codebase.

**Actions**:

1. Read `~/.claude/workbench-root` for workbench path. Read `config.yaml` for user identity and org context.
2. Check for existing plan directory at `<workbench>/context/plans/active/<name>/`. Read any existing artifacts (state.md, research.md, analysis.md).
3. **Standalone mode**: Ask the user: "What is your goal?" Get them to describe the feature or change they want to build.
4. **Forge-integrated mode**: Read state.md User Context section. Summarize: "From forge, I know: [summary]. I'll focus the PRD interview on product definition gaps."
5. Ask if they have supporting materials: existing documents, Figma mocks, Jira tickets, or other references.
6. If a Figma URL is provided and Figma MCP is available, use `get_screenshot` and `get_design_context` to pull design details.
7. If an existing document is referenced, read it.
8. If a Jira ticket is referenced and Atlassian MCP is available, fetch its details.

---

## Phase 2: Codebase Exploration (Opt-in)

**Goal**: Understand current capabilities and patterns relevant to this feature. The user does NOT need to be involved in this phase.

**Trigger**: Only runs when `--explore` flag is passed.

**Actions**:

1. Launch up to 3 sub-agents (`Explore` type) to understand:
   - What related features already exist
   - Current user flows in the area being changed
   - Data models and API endpoints relevant to this feature
   - UI components and pages that may be affected
2. Summarize findings internally — these inform your questions but are NOT exposed to the user

---

## Phase 3: Interview

**Goal**: Ask high-level product questions to eliminate ambiguity. Questions should be answerable by a product owner or stakeholder without engineering knowledge.

**CRITICAL**: This is the most important phase. Do NOT skip or rush it.

**Actions**:

1. Use `AskUserQuestion` tool to cover these areas:

   **Existing Functionality**:
   - Is this building on an existing feature? If so, what does it do currently?
   - Clarify terminology — the user may use different language than the codebase. Confirm you're talking about the same thing before proceeding.
   - What works well today that should be preserved?
   - What specifically needs to change or be added?

   **User Stories & Personas**:
   - Who are the target users for this feature?
   - What problem does this solve for them?
   - What is the primary user flow?
   - Are there different user types with different needs?

   **Scope & Boundaries**:
   - What is in scope for the initial release (MVP)?
   - What is explicitly out of scope or deferred?
   - Are there dependencies on other features or teams?
   - What existing behavior should NOT change?

   **Success Criteria**:
   - How do we know this feature is working correctly?
   - What does success look like from the user's perspective?
   - Are there measurable goals (metrics, KPIs)?

   **Edge Cases & Risks**:
   - What happens when things go wrong (errors, empty states, permissions)?
   - Are there data migration or backwards compatibility concerns?
   - What are the most likely user mistakes?
   - Are there performance or scale considerations?

2. **Forge-integrated mode**: Skip topics already answered in state.md User Context (typically: "what are you building", "who benefits", "success criteria", "scope boundaries"). Focus on product-definition gaps: detailed user flows, edge case behaviors, visual states, non-functional requirements.

3. Continue interviewing until all ambiguities are resolved. There is no limit on questions — ask as many rounds as needed.

4. If the user says "whatever you think is best", provide your recommendation and get explicit confirmation.

5. If Figma mocks were provided, reference specific design elements when asking about behavior and interactions.

---

## Phase 4: Write PRD

**Goal**: Produce the PRD document.

**Actions**:

1. Write the PRD following the template at `references/prd-template.md` (relative to this skill).
2. Save to `<workbench>/context/plans/active/<name>/prd.md`
3. Output the full PRD content directly to the user so they can review it immediately.

---

## Phase 5: Generate HTML Mockups

**Goal**: Create visual UI mockups as HTML files for the key screens described in the PRD.

**Actions**:

1. **Identify screens** — Review the PRD's User Stories and Design sections. List each distinct screen or state that needs a mockup (typically 2-5 screens for an MVP feature). Use `AskUserQuestion` to confirm the screen list with the user before proceeding.

2. **Load mockup template** — Read the template at `references/mockup-template.html` (relative to this skill) to understand the design system tokens and component patterns.

3. **Generate HTML mockups** — For each screen:
   - Copy the mockup template
   - Replace `<!-- SCREEN TITLE -->` with the screen name
   - Replace the `<!-- CONTENT -->` comment with the screen content using plain HTML styled with Tailwind classes and design system tokens
   - Use the component pattern recipes from the template comments (Card, Button, Input, Table, Badge, Tabs, Dialog, etc.)
   - Include realistic placeholder data from the PRD context — never use "Lorem ipsum"
   - Save each file to `<workbench>/context/plans/active/<name>/mocks/{screen-name}.html`

4. **Serve the mockups locally** — Start a lightweight HTTP server in the background for preview:
   ```bash
   npx serve <workbench>/context/plans/active/<name>/mocks --port 54321 &
   ```
   Tell the user: "Mockups are available at http://localhost:54321/ — open in your browser to preview."

5. **Stop the server** — When the user is done reviewing, kill the background serve process.

6. **Update the PRD** — Add mockup references to the PRD's Design section with the screen table.

> **Note**: The mockup template uses a generic design system with semantic color tokens, typography utilities, and component recipes. For project-specific mockups, customize `references/mockup-template.html` with your project's design tokens, colors, and typography. This is a known gap — the default template works as wireframe-level reference for any project.

> **Future enhancement**: When Figma MCP adds a `generate_figma_design` tool for HTML-to-Figma capture, Phase 5 can be extended to automatically push mockups into Figma.

---

## Phase 6: Review & Iterate

**Goal**: Get user sign-off on the PRD.

**Actions**:

1. Ask the user to review the PRD
2. If the user requests changes, update the document and re-present
3. Once approved, confirm the PRD is final

---

## Phase 7: Finalize

**Goal**: Save final artifacts and signal completion.

**Actions**:

1. Ensure `prd.md` and `mocks/` are saved to `<workbench>/context/plans/active/<name>/`
2. If in forge-integrated mode, update state.md to note PRD completion
3. Present summary:
   - PRD location
   - Number of mockup screens generated
   - Suggested next step:
     - **Standalone**: "Run `/forge <name>` to create an engineering plan, or use this PRD directly for stakeholder review."
     - **Forge-integrated**: "PRD complete. Continuing with plan creation."
