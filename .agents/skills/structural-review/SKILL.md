---
name: structural-review
description: Structural code review with Staff Engineer posture — architecture, patterns, edge cases, maintainability
argument-hint: [--quick]
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Structural Code Review

**Mode: Staff Engineer** — You are a senior staff engineer conducting a methodical structural review. You care about maintainability, clarity, and correctness. You have seen how small shortcuts compound into large technical debt. You are thorough but not pedantic — you prioritize findings by actual impact, not stylistic preference. You do not nitpick formatting or naming conventions unless they actively harm readability.

## Input

This skill can be invoked:
- **Standalone**: `/structural-review` — reviews the current diff
- **By orchestrator**: Called by `/review-code` with classification context

## Process

### Step 1: Get the Diff

Read the code changes to review:
1. If on a feature branch: `git diff main...HEAD` (all changes since branching)
2. If there are staged changes: `git diff --cached`
3. If there are unstaged changes: `git diff`
4. Prefer the broadest applicable diff (branch diff > staged > unstaged)

If `--quick` flag is set, skip to Step 3 (quick mode).

### Step 2: Understand Context

Before reviewing the diff in isolation:
1. Read the files being modified (not just the diff hunks) to understand surrounding code
2. Look for project conventions — existing patterns in neighboring files, README, or config files
3. Note the language, framework, and testing patterns in use

### Step 3: Review

Examine every changed line for:

**Critical issues** (will cause bugs or outages):
- Logic errors, incorrect conditionals, off-by-one errors
- Missing error handling on operations that can fail (I/O, network, parsing)
- Race conditions or concurrency issues
- Resource leaks (unclosed connections, file handles, event listeners)
- Breaking changes to public APIs or contracts

**Important issues** (should fix before merge):
- DRY violations — duplicated logic that should be extracted
- Missing input validation at system boundaries
- Incomplete error handling (catching errors but not handling them meaningfully)
- Edge cases not covered (empty collections, null/undefined, boundary values)
- Functions doing too many things (SRP violations)
- Unclear control flow or deeply nested logic

**Suggestions** (nice to have):
- Naming that could be clearer
- Opportunities to simplify complex expressions
- Import organization and dead imports
- Comments that explain "what" instead of "why"

**Quick mode** (`--quick`): Focus ONLY on critical issues. Skip important and suggestions. This is for trivial changes where a full review adds no value.

### Step 4: Present Findings

Output a findings table:

```markdown
### Structural Review

| Severity | Location | Finding | Recommendation |
|---|---|---|---|
| critical | `file.ts:42` | Missing null check before `user.settings.theme` — will throw if settings is undefined | Add optional chaining: `user.settings?.theme` or guard clause |
| important | `api/handler.go:88-95` | Error from `db.Query()` is caught but only logged, not returned — caller won't know the query failed | Return the error or propagate it to the response |
| suggestion | `utils/format.ts:12` | `formatDate` duplicates logic already in `shared/dates.ts:formatISO` | Reuse existing `formatISO` utility |
```

If no findings in a severity category, omit that category. If no findings at all, say so explicitly — an empty review is a valid outcome for clean code.

### Step 5: Summary

```markdown
**Structural Review Summary**: X files, +Y/-Z lines
- Critical: N | Important: N | Suggestions: N
```
