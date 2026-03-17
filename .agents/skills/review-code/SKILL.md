---
name: review-code
description: Adaptive code review orchestrator — classifies diff and invokes structural, security, QA, and test sub-skills
argument-hint: [--quick] [--security-only] [--no-security] [--qa-only] [--no-qa]
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
/review-code                    # Adaptive — classifies diff, runs appropriate sub-skills
/review-code --quick            # Structural review only (quick mode) — for trivial changes
/review-code --security-only    # Security scan only
/review-code --no-security      # Skip security scan
/review-code --qa-only          # QA check only
/review-code --no-qa            # Skip QA check and test suggestions
```

## Sub-Skills

This orchestrator invokes these standalone skills based on classification:

| Sub-Skill | Posture | What It Does |
|---|---|---|
| `/structural-review` | Staff Engineer | Architecture, patterns, DRY, edge cases, error handling |
| `/security-scan` | Security Engineer | OWASP Top 10, secrets detection, dependency risks |
| `/qa-check` | QA Lead | Diff-aware test gap analysis, regression risk |
| `/test-suggest` | TDD Coach | Framework-aware test skeletons, red-green-refactor |

Each sub-skill can also be invoked directly for standalone use.

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
| Trivial | `/structural-review --quick` |
| Standard | `/structural-review` + `/qa-check` |
| Security-sensitive | `/structural-review` + `/security-scan` + `/qa-check` |
| New feature | `/structural-review` + `/security-scan` + `/qa-check` + `/test-suggest` |

Run each sub-skill's full process. Collect all outputs.

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

### Overall Summary

| Category | Critical | High/Important | Medium/Suggestion | Low |
|---|---|---|---|---|
| Structural | N | N | N | — |
| Security | N | N | N | N |
| Test gaps | — | N | N | N |

**Top action items**:
1. [Most critical finding with location]
2. [Second most critical finding]
3. [Third most critical finding]

> Address critical and high findings before creating your PR.
```

Only include sections for sub-skills that were invoked. If a sub-skill found no issues, include it with a clean result — an empty section is a positive signal.
