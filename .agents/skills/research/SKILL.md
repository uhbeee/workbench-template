---
name: research
description: Multi-source research methodology with confidence ratings. Searches Confluence, Jira, Slack, and the web. Produces structured findings with source quality ratings. Use when investigating a technology choice, gathering context on a feature, or building an evidence base.
metadata:
  workbench.argument-hint: "<topic-or-plan-name> [description]"
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.codex/workbench-root` or `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Research Methodology

Systematically gather evidence on a question or topic — searching internal systems (Confluence, Jira, Slack), the web, and prior research — then present structured, evidence-based findings. You do not make recommendations. You present facts, context, and confidence levels so the user can decide.

## The Core Problem

Research is time-consuming. Searching Confluence, reading Slack history, scanning industry blogs, and synthesizing findings across sources takes hours. This methodology compresses that work into a structured, repeatable process with clear source attribution and confidence ratings.

## Differentiation from the Sounding Board

The **sounding board** is adversarial — it challenges ideas with frameworks and counterarguments.
The **researcher** is investigative — it gathers evidence and presents facts.

They compose well: research first to build the evidence base, then sounding board to stress-test conclusions.

## Input

The user will present a research question. It might be:
- A technology evaluation ("What are the tradeoffs of gRPC vs REST for inter-service communication?")
- A factual question ("What's our current approach to rate limiting?")
- A strategic question ("How are companies handling AI agent orchestration at scale?")
- A comparison ("Redis Streams vs Kafka for our event pipeline?")
- An investigation ("What happened with the last migration to microservices?")
- A concept validation ("Is event sourcing a good fit for our audit trail requirements?")

## Process

### Step 1: Load Context

Before anything else:

1. **Read `config.yaml`** from the repository root for Confluence spaces, Jira projects, and Slack channels.
2. **Check `context/notes/research/`** for prior research that relates to the current question. Prior research compounds — always build on what exists.
3. **Check `context/plans/active/`** — if the first argument matches a plan directory name, this research is part of a feature plan pipeline.
4. **Invoke the `repo-context` skill** when the question involves internal systems, repos, services, product flows, validation, or debugging. Use its bundled helper for deterministic output:
   - `python3 <workbench-root>/.agents/skills/repo-context/scripts/repo_context.py explain --current --include-adjacent`
   - or `python3 <workbench-root>/.agents/skills/repo-context/scripts/repo_context.py explain --repo <repo> --include-adjacent`
   - or `python3 <workbench-root>/.agents/skills/repo-context/scripts/repo_context.py explain --service <service> --include-adjacent`
   Use repo-context to bound the search, identify adjacent repos/services, and capture repo-specific rule entrypoints. If saving `research.html`, include repo-context as a source anchor and link any generated scoped packet.

### Step 2: Gather Context from the User

**Before searching anything, use `AskUserQuestion` to understand where to look.** The user knows their codebase and org — leverage that. Ask about:

- **Codebase pointers**: For questions that involve internal systems — "Which repos, directories, or files are most relevant? Where does the current implementation live?" This avoids blind searching across the entire org.
- **Slack/Jira/Confluence pointers**: "Are there specific Slack threads, Jira tickets, or Confluence docs I should look at?" The user often knows exactly where the relevant discussion happened.
- **Depth**: If not obvious from the question — "Is this a quick lookup or do you want a deep dive?"
- **Scope boundaries**: If the question could go in multiple directions — "Which aspect should I focus on?"

**Adapt the questions to the research type.** A purely external technology evaluation doesn't need codebase pointers. A factual lookup about an internal system doesn't need depth confirmation. Ask what's relevant, skip what isn't.

If the user provides enough context in their initial prompt (e.g., they name specific repos, link files, or specify depth), skip the questions that are already answered. For quick lookups, skip this step entirely and go straight to searching.

### Step 3: Classify Depth

Determine the research depth. If the user specifies one, use it. If not, infer from the question type. **If the appropriate depth is unclear, use `AskUserQuestion` to confirm with the user before proceeding** — especially for standard and deep dive, which consume significant search budget.

| Level | When to Use | Search Budget | Sub-questions | Self-refine |
|-------|-------------|---------------|---------------|-------------|
| **Quick lookup** | Factual questions, single-concept answers | 3-5 searches | None (direct search) | No |
| **Standard research** | Tech evaluations, tradeoff analysis | 8-12 searches | 3-4 | No |
| **Deep dive** | Strategic bets, multi-dimensional comparisons | 15-20 searches | 4-6 | Yes (1 pass, max 3 follow-ups) |

**Quick lookup** is for questions with a single, locatable answer: "What library do we use for X?", "What does our ADR say about Y?"

**Standard research** is for questions that need multiple perspectives: "What are the tradeoffs of X vs Y?", "How should we approach Z?"

**Deep dive** is for questions where getting it wrong is expensive: "Should we adopt X as a platform-wide standard?", "What's our migration strategy for Y?"

### Step 4: Decompose the Question (Standard+ Only)

Break the research question into focused sub-questions. Each sub-question should be answerable independently.

**Always include a counter-evidence sub-question.** If the user is asking about adopting X, one sub-question must be: "What are the failure cases / downsides / risks of X?" This prevents confirmation bias in the research.

Example decomposition for "Should we use gRPC for inter-service communication?":
1. What are gRPC's technical tradeoffs vs REST for our use cases?
2. What does our internal codebase already use, and what would change?
3. What do companies at our scale report after adopting gRPC?
4. What are the failure cases and operational pain points of gRPC?

### Step 5: Codebase Exploration

For questions that involve internal systems, architecture, or implementation — explore the actual code. **The codebase is a primary source.** Docs can be stale; code is ground truth.

**Use the pointers from Step 2.** Start with any files/directories the user pointed to, then explore outward:
- Start with repo-context's current repo, matched services, one-hop adjacent services, `context_files`, `repo_rule_entrypoints`, `instruction_dirs`, and service `inspect_first`.
- Read repo-specific rule entrypoints before exploring or interpreting a target repo.
- Use `Glob` to find relevant files by pattern (e.g., `**/*RateLimiter*`, `**/services/**/*.cs`)
- Use `Grep` to search for specific patterns, interfaces, usage of the technology under discussion
- Use `Read` to examine key files — current implementations, abstractions, configuration, tests
- Focus on: how it currently works, what patterns are in use, what depends on what, test coverage

**What to look for depends on the question type:**
- **"What's our current approach to X?"** — find the implementation, trace the call chain, note the patterns
- **"Should we adopt X?"** — find what currently fills that role, what depends on it, what would change
- **"What happened with the migration to X?"** — find before/after code, partial migrations, TODO comments
- **"Is X a good fit for Y?"** — find Y's current implementation, understand its constraints and interfaces

**Skip codebase exploration when it doesn't apply.** Purely external technology comparisons, strategic questions about industry trends, and questions with no internal codebase angle don't need code review.

### Step 6: Internal Research

Search internal systems for prior art, decisions, and tribal knowledge. **Internal context is always more valuable than external** — a team post-mortem outweighs 10 external blog posts.

**Confluence** — search for ADRs, RFCs, design docs, and post-mortems:
- Use `mcp__claude_ai_Atlassian__searchConfluenceUsingCql` with relevant keywords across all spaces from `config.yaml: confluence.spaces[]`
- Read the most relevant results with `mcp__claude_ai_Atlassian__getConfluencePage`
- Check page comments with `mcp__claude_ai_Atlassian__getConfluencePageFooterComments` for additional context and dissenting views
- Look for: past decisions on this topic, post-mortems from similar approaches, existing RFCs, ADRs
- If the user pointed to specific Confluence pages in Step 2, read those first

**Jira** — search for prior attempts, related work, and known issues:
- Use `mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql` across all projects from `config.yaml: jira.projects[]`
- Look for: tickets where this was attempted before, related tech debt, epics that overlap, spike tickets with findings
- If the user pointed to specific tickets in Step 2, read those first

**Slack** — search for prior discussions and informal decisions:
- Use `mcp__claude_ai_Slack_MCP__slack_search_public_and_private` with relevant keywords
- Read important threads with `mcp__claude_ai_Slack_MCP__slack_read_thread`
- Slack threads often contain the real reasoning behind decisions that never made it into docs — find it
- If the user pointed to specific threads in Step 2, read those first

**Skip sources that don't apply.** A factual lookup about an external technology doesn't need Jira searches. Match research effort to the question.

### Step 7: External Research

Search the web for industry perspective, benchmarks, and experience reports.

Use `WebSearch` with varied search angles to avoid confirmation bias:
- **Direct**: "[topic] tradeoffs", "[technology] production experience"
- **Experience reports**: "[technology] at scale", "[technology] migration lessons"
- **Failure cases**: "[technology] problems", "[technology] why we stopped using", "[technology] regret"
- **Comparisons**: "[option A] vs [option B] production", "[option A] vs [option B] benchmark"

Use `WebFetch` to read the most promising results in detail. Don't just skim titles — the nuance is in the content.

**Search budget by depth:**
- Quick lookup: 1-2 web searches
- Standard: 3-5 web searches, fetch 2-3 articles
- Deep dive: 5-8 web searches, fetch 4-6 articles

### Step 8: Rate Source Quality

Every source gets a quality rating:

| Rating | Criteria | Examples |
|--------|----------|---------|
| **High** | Production experience, benchmarks with methodology, official documentation, organizational post-mortems | Company engineering blog with metrics, official migration guide, internal post-mortem |
| **Medium** | Reputable technical blogs, conference talks, well-reasoned analysis with caveats | InfoQ article, KubeCon talk summary, thoughtful comparison post |
| **Low** | Opinion without evidence, vendor marketing content, outdated material (>2 years for fast-moving topics) | Vendor "why you should use our product" post, undated blog, Stack Overflow answer from 2018 |

Low-quality sources are flagged but still included if they provide unique perspectives. The rating tells the user how much weight to give each source.

### Step 9: Synthesize Findings

For each sub-question (or the main question for quick lookups):

1. **State the consensus finding** — what does the weight of evidence say?
2. **Assign a confidence level**:
   - **High**: Multiple strong sources agree, internal experience confirms
   - **Medium**: Some evidence, reasonable extrapolation, or sources partially conflict
   - **Low**: Limited evidence, reasoning from general principles, or significant conflicting evidence
3. **Note conflicting evidence** — proportionally. If 8 sources agree and 1 disagrees, say "strong consensus with one dissenting view" rather than presenting it as a 50/50 debate. No false balance.

### Step 10: Self-refine (Deep Dive Only)

After initial synthesis, do one refinement pass:

1. **Coverage check**: Are there sub-questions with only low-confidence answers? Are there obvious angles not yet explored?
2. **Contradiction resolution**: Where sources conflict, can a follow-up search resolve the conflict?
3. **Recency check**: Are any key findings based on outdated information? Has the landscape changed?

Execute up to 3 follow-up searches to fill the most critical gaps. Then stop — diminishing returns are real.

### Step 11: Produce the Report

If the report is saved to disk, shared, or handed to another agent/engineer, read `context/standards/html-plan-standard.md` (the Artifact Format Standard). Research reports default to **Markdown-first** — they're text-heavy and agents read them just as often as humans. The executive summary answers the question upfront; everything else is for drilling down.

Generate an HTML companion only when the research has substantial visual content the MD can't carry (architecture comparison diagrams, multi-vendor matrices with semantic colors, side-by-side mockups). Mostly-prose research reports stay MD-only.

### Step 12: Persist and Offer Next Steps

1. **Save the report**:
   - If `context/plans/active/$0/` exists (where `$0` is the first argument), save the primary report to `context/plans/active/$0/research.md` and update `state.md`.
   - Otherwise, save the primary report to `context/notes/research/YYYY-MM-DD-slug.md` where `slug` is a short kebab-case description (e.g., `2026-02-08-grpc-vs-rest.md`).
   - Generate `research.html` (or `YYYY-MM-DD-slug.html`) as a visual companion only when the visual-content criteria above are met.
2. **Offer next steps** based on what makes sense:
   - Run `/sounding-board` to stress-test conclusions
   - Do a **deep dive** if this was a quick/standard research (escalate depth)
   - Run `/plan-create` to create a strategic plan if the research supports a decision
   - Create a **Jira ticket** for follow-up work identified
   - Draft a **Confluence doc** summarizing findings for the team
   - Run the **estimate** agent if the research supports a decision that needs sizing

## HTML Report Structure

Create a self-contained HTML page with these sections:

- top summary band: topic, date, depth, question, bottom line, confidence distribution, and known gap count,
- executive summary: 3-6 key findings with confidence labels,
- sub-question findings: consensus answer, confidence, supporting evidence, and conflicting evidence,
- counter-evidence: risks, downsides, failure cases, or dissenting sources,
- internal context: codebase findings, Confluence/Jira/Slack context, prior research, and internal knowledge gaps,
- synthesis: how the evidence fits together,
- implications: what changes if the direction is pursued or not pursued,
- sources table: source name/link, type, quality, key takeaway,
- research quality: depth, source counts, confidence distribution, known gaps, and staleness risk.

For quick lookups, use the same HTML shell but simplify it to: answer, confidence, source table, and known gaps.

## Key Principles

- **Evidence over opinion.** Present facts, not recommendations. The sounding board makes recommendations — the researcher provides the evidence base.
- **Internal context is king.** A team post-mortem about migrating to X is worth more than 10 external "X vs Y" blog posts. Always search internal sources first and weight them higher.
- **No false balance.** If the evidence overwhelmingly supports one conclusion, say so. Don't manufacture a balanced view when one doesn't exist. State the weight of evidence honestly.
- **Executive summary answers the question.** Readers should get the answer in the first 30 seconds. Everything below the summary is for people who want to drill deeper.
- **Prior research compounds.** Always check `context/notes/research/` for related prior work. Reference it, build on it, note where findings have changed.
- **Confidence is honest.** High means strong evidence. Medium means reasonable inference. Low means best guess. Never inflate confidence to sound more authoritative.
- **Source quality is transparent.** Every source is rated. The user decides how much weight to give vendor content vs production experience reports.
- **Stay in your lane.** Gather and present evidence. Don't slip into making recommendations, challenging assumptions, or being adversarial — that's what the sounding board is for.
- **Ask, don't assume.** When the question is ambiguous, the scope is unclear, or you need to make a judgment call that affects the research direction, use `AskUserQuestion` to clarify. A 30-second question saves 10 minutes of wrong-direction research.

## Important Notes

- **This is a principal engineer.** Don't explain basic concepts. Focus on the evidence that informs decisions at the systems and organizational level.
- **Speed-match the question.** A quick lookup should take 2 minutes, not 20. A deep dive earns its thoroughness. Don't over-research simple questions or under-research strategic ones.
- **Respect the search budget.** The depth levels exist to prevent runaway research. Stick to the budget. If you need more searches than the budget allows, note it as a gap and let the user decide whether to escalate depth.
- **Prefer recent sources.** For fast-moving topics (cloud services, AI/ML, frameworks), prefer sources from the last 12-18 months. Flag older sources explicitly.
- **Use `AskUserQuestion` for any clarification.** Don't guess at the user's intent. If the question could go multiple directions, if you're unsure about depth, or if you hit a fork in the research — ask.
