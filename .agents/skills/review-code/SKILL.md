---
name: review-code
description: Adaptive code review orchestrator — classifies diff and invokes structural, security, QA, test, and CodeRabbit sub-skills
argument-hint: [--quick] [--security-only] [--no-security] [--qa-only] [--no-qa] [--no-cr] [--cr-rules <file>] [--cr-only]
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# /review-code — Adaptive Code Review

One command, comprehensive review. Reads the diff, classifies the change, and invokes the right combination of review sub-skills automatically.

## Why You Must Not Skip This

| Temptation | Reality |
|---|---|
| "This is a simple change, no review needed" | Simple changes cause the most insidious bugs — they skip scrutiny |
| "I wrote this code, I know it's correct" | Author blindness is the #1 source of missed bugs |
| "It's just a refactor, nothing changed" | Refactors are where subtle behavioral changes hide |
| "Tests are passing, so it's fine" | Tests verify what you thought to test, not what you didn't |
| "This is urgent, no time for review" | Urgent code that ships broken creates more urgency |
| "The diff is too large for meaningful review" | Large diffs need MORE review, not less — break it down |

## Interaction Model

**Always use `AskUserQuestion`** when you need user input — classification overrides, which findings to address, whether to re-run after fixes. Never guess at the user's intent. Present clear options with context.

## Usage

```
/review-code                    # Adaptive — classifies diff, runs sub-skills + CodeRabbit
/review-code --quick            # Structural review only (quick mode) — for trivial changes
/review-code --security-only    # Security scan only
/review-code --no-security      # Skip security scan
/review-code --qa-only          # QA check only
/review-code --no-qa            # Skip QA check and test suggestions
/review-code --no-cr            # Skip CodeRabbit (faster, offline-friendly)
/review-code --cr-rules file.md # CodeRabbit with custom instruction file (-c flag)
/review-code --cr-only          # CodeRabbit review only (skip all local sub-skills)
```

## Sub-Skills

This orchestrator invokes these standalone skills based on classification:

| Sub-Skill | Posture | What It Does |
|---|---|---|
| `/structural-review` | Staff Engineer | Architecture, patterns, DRY, edge cases, error handling |
| `/security-scan` | Security Engineer | OWASP Top 10, secrets detection, dependency risks |
| `/qa-check` | QA Lead | Diff-aware test gap analysis, regression risk |
| `/test-suggest` | TDD Coach | Framework-aware test skeletons, red-green-refactor |
| CodeRabbit CLI | External AI | Cloud-based review via `cr` — broad pattern detection, cross-file analysis |

Each sub-skill can also be invoked directly for standalone use.

### CodeRabbit CLI

[CodeRabbit](https://coderabbit.ai) provides cloud-based AI code review via the `cr` CLI. It complements local sub-skills by catching patterns they miss (cross-file impact, API misuse, broader ecosystem issues).

**Trade-offs**:
- Adds 7-30 minutes of latency (cloud processing)
- Rate-limited: 3 reviews/hour (free), 8/hour (pro)
- Requires authentication (`cr auth login`) and a git repo with diffs
- Not a replacement for local sub-skills — it's an additional signal

**Default behavior**: CodeRabbit runs automatically on every review. Use `--no-cr` to skip (e.g., offline, quick iteration, rate limit conservation).

## Process

### Step 1: Get the Diff

Determine what to review:
1. If on a feature branch: use `git diff main...HEAD` (all changes since branching)
2. If there are staged changes: use `git diff --cached`
3. If there are unstaged changes: use `git diff`
4. Prefer the broadest applicable diff

Run `git diff --stat` to get file count and line count for the summary.

### Step 2: Check for Flag Overrides

If the user passed flags, skip classification and route directly:
- `--quick` → invoke `/structural-review --quick` only
- `--security-only` → invoke `/security-scan` only
- `--qa-only` → invoke `/qa-check` only
- `--no-security` → exclude `/security-scan` from whatever classification produces
- `--no-qa` → exclude `/qa-check` and `/test-suggest` from whatever classification produces
- `--no-cr` → skip CodeRabbit CLI (faster, offline-friendly)
- `--cr-rules <file>` → pass `<file>` to CodeRabbit's `-c` flag for custom instructions
- `--cr-only` → run CodeRabbit CLI only, skip all local sub-skills

If flags are set, skip to Step 4.

### Step 3: Classify the Change

Analyze the diff to determine what kind of review is needed.

**Trivial** — Quick structural check only:
- Less than 20 changed lines AND
- No logic changes (only comments, formatting, renames, imports, whitespace)

**Security-sensitive** — Full structural + deep security + QA:
- File paths match security patterns: `auth*`, `login*`, `session*`, `middleware*`, `api/*`, `routes/*`, `*password*`, `*token*`, `*secret*`, `*.env*`, `*permission*`, `*role*`, `*crypto*`, `*certificate*`
- OR diff content contains security-relevant terms: `password`, `secret`, `token`, `api_key`, `credentials`, `Authorization`, `cookie`, `session`, `encrypt`, `decrypt`, `hash`, `salt`, `csrf`, `cors`, `permission`, `role`, `admin`

**New feature** — Full pass including test suggestions:
- New files added (git status shows untracked or newly staged files)
- OR new route/endpoint definitions detected
- OR new exported functions/classes/components

**Standard** — Structural + QA (everything else):
- Logic changes, refactors, bug fixes that don't match above categories

### Step 4: Invoke Sub-Skills

Based on classification (or flags), invoke the appropriate sub-skills:

| Classification | Sub-Skills Invoked |
|---|---|
| Trivial | `/structural-review --quick` + CodeRabbit |
| Standard | `/structural-review` + `/qa-check` + CodeRabbit |
| Security-sensitive | `/structural-review` + `/security-scan` + `/qa-check` + CodeRabbit |
| New feature | `/structural-review` + `/security-scan` + `/qa-check` + `/test-suggest` + CodeRabbit |

CodeRabbit runs by default for all classifications. Use `--no-cr` to skip it.
If `--cr-only` is set, skip all local sub-skills and only run CodeRabbit.

Run each sub-skill's full process. Collect all outputs.

### Step 4a: Run CodeRabbit CLI (always, unless `--no-cr` is set)

**Prerequisites**: Verify CodeRabbit is available and authenticated:
```bash
cr auth status
```
If not authenticated, tell the user to run `cr auth login` and stop.

**Launch CodeRabbit in background** (it takes 7-30 min) while local sub-skills run in parallel:

1. Determine the base branch (same logic as Step 1):
   - Feature branch → `--base main` (or whatever the main branch is)
   - Staged/unstaged only → `--type uncommitted` or `--type committed`

2. Build the command:
   ```bash
   # Standard — token-efficient output for agent consumption
   cr --prompt-only --base main

   # With custom rules file
   cr --prompt-only --base main -c <rules-file>

   # For uncommitted changes only
   cr --prompt-only --type uncommitted
   ```

3. Run via `Bash` with `run_in_background: true` and a 10-minute timeout. Continue with local sub-skills while waiting.

4. When CodeRabbit completes, parse the output:
   - Findings are separated by `=====` blocks
   - Each block contains: file path, line number, severity, and suggestion
   - Map severities to the unified report format: critical, high, medium, low

**Rate limit awareness**: Free tier allows 3 reviews/hour, pro allows 8/hour. If you get a rate limit error, inform the user and skip CodeRabbit — do not retry.

**If CodeRabbit times out or fails**: Include a note in the report that CodeRabbit was requested but did not complete. Do not block the rest of the review.

### Step 5: Assemble Output

Combine all sub-skill outputs into a unified report:

```markdown
## /review-code Results

**Classification**: [Trivial | Standard | Security-sensitive | New feature]
**Diff**: X files changed, +Y/-Z lines
**Flags**: [any overrides applied, or "none — adaptive classification"]
**Sub-skills invoked**: [list]

---

### Structural Review
[Full output from /structural-review]

---

### Security Scan
[Full output from /security-scan — only if invoked]

---

### Test Coverage & QA
[Full output from /qa-check — only if invoked]

---

### Test Suggestions
[Full output from /test-suggest — only if invoked]

---

### CodeRabbit Review
[Parsed findings from `cr --prompt-only` — included by default, absent only if `--no-cr` was set]

For each CodeRabbit finding, format as:
- **[severity]** `file:line` — suggestion text

If CodeRabbit timed out or hit rate limits, note:
> CodeRabbit was requested but [timed out | hit rate limit]. Local sub-skill results are complete.

Deduplicate: if CodeRabbit flags the same issue as a local sub-skill, note it as "also flagged by CodeRabbit" in the local finding rather than listing it twice.

---

### Overall Summary

| Category | Critical | High/Important | Medium/Suggestion | Low |
|---|---|---|---|---|
| Structural | N | N | N | — |
| Security | N | N | N | N |
| Test gaps | — | N | N | N |
| CodeRabbit | N | N | N | N |

**Top action items**:
1. [Most critical finding with location]
2. [Second most critical finding]
3. [Third most critical finding]

> Address critical and high findings before creating your PR.
```

Only include sections for sub-skills that were invoked. If a sub-skill found no issues, include it with a clean result — an empty section is a positive signal.
