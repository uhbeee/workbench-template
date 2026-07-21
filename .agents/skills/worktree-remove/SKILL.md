---
name: worktree-remove
description: Safely remove or audit managed Workbench feature, hotfix, review, or release worktrees using guarded dry-run first. Use when the user asks to remove, delete, clean up, prune, audit, retire a worktree, list stale worktrees, or remove worktrees with merged PRs; never use for main/develop/master checkouts.
compatibility: macOS or Windows Workbench setup with Git and Python 3. Uses scripts/wt_remove.py and scripts/wt_cleanup.py, symlinks to the canonical Workbench scripts in scripts/worktrees/.
metadata:
  workbench.argument-hint: "<single-remove>|--merged-to|--audit|--execute clean-merged [--repo <repo>] [--yes] [--keep-branch|--delete-branch] [--force] [--dry-run]"
---

# Remove or Audit Worktrees

Use this skill for guarded inspection and cleanup of managed Workbench worktrees. Two scripts:

- `wt_remove.py` — remove a single worktree or all worktrees merged to a base branch (per-target removal primitive).
- `wt_cleanup.py` — read-only audit across all repos with PR state + dirt classification; optional bulk execute mode that delegates to `wt_remove.py`.

## Safety Model

Removal is destructive. Run a dry-run or audit first; only execute after explicit user approval.

Protected checkouts are never valid targets:

- `main`, `develop`, `master`
- repo base directories ending in `.git`

The bulk audit/cleanup pipeline never force-removes worktrees with **real uncommitted code**. Files that match the dirt allowlist (`.claude/`, `.codex/`, `.agent/`, `AGENTS.md`, screenshots, etc.) are treated as throwaway tooling residue.

## Audit and Bulk Cleanup (preferred for multi-repo work)

```bash
# Read-only audit across every managed repo (queries gh per branch)
python3 scripts/wt_cleanup.py

# Audit a single repo (alias resolution: search-mcp, admin-ui, admin-api, runtime all work)
python3 scripts/wt_cleanup.py --repo recruit-ui

# Faster audit without PR queries
python3 scripts/wt_cleanup.py --no-pr-check

# Machine-readable
python3 scripts/wt_cleanup.py --format json

# Remove every clean+merged worktree across all repos (keep branches by default)
python3 scripts/wt_cleanup.py --execute clean-merged --yes

# Also remove worktrees whose only dirt is AI tooling files (uses --force under the hood)
python3 scripts/wt_cleanup.py --execute clean-merged,dirty-tooling-only --yes

# Include stale clean-with-no-PR worktrees (40+ commits behind base by default)
python3 scripts/wt_cleanup.py --execute clean-merged,dirty-tooling-only,clean-stale --yes
```

Classifications produced by the audit:

| Classification | Meaning | Recommendation |
|---|---|---|
| `clean-merged` | Clean working tree, PR is MERGED | `remove` |
| `clean-stale` | Clean, no PR, >= 40 commits behind base | `remove_or_review` |
| `clean-open-pr` | Clean, PR is OPEN | `keep` |
| `clean-no-pr` | Clean, no PR, commits ahead of base | `review` |
| `clean-no-progress` | Clean, no PR, no commits, not stale | `remove_or_review` |
| `dirty-tooling-only` | Only ignored AI tooling files dirty | `force_remove_safe` |
| `dirty-real` | Real uncommitted code changes | `keep_or_review` |
| `dirty-real-merged` | Real uncommitted code, but PR is merged | `review_before_removing` |
| `dirty-real-open-pr` | Real uncommitted code, PR is open | `keep` |
| `protected` | main/develop/master | `skip` |

Only `clean-merged`, `clean-stale`, and `dirty-tooling-only` are removable via `--execute`. Everything else requires per-target action via `wt_remove.py`.

The dirt allowlist lives at `context/repo-context/dirt-allowlist.yaml` (global patterns + per-repo overrides). Override with `--allowlist <path>` or disable with `--include-tooling-dirt`.

Aliases resolve via `context/repo-context/repos.yaml` `aliases:` entries (so `--repo admin-ui` finds `react-admin`).

## Single-Worktree Removal (precise control)

Dry-run first:

```bash
python3 scripts/wt_remove.py --repo <repo> <worktree-name> --dry-run
```

Dry-run all clean worktrees that are an ancestor of a target branch (fast-forward only):

```bash
python3 scripts/wt_remove.py --merged-to develop --dry-run
python3 scripts/wt_remove.py --repo <repo> --merged-to develop --dry-run
```

Confirmed removal while keeping the local branch:

```bash
python3 scripts/wt_remove.py --repo <repo> <worktree-name> --yes --keep-branch
```

Windows Python launcher:

```bat
py -3 scripts\wt_remove.py --repo <repo> <worktree-name> --yes --keep-branch
py -3 scripts\wt_cleanup.py --repo <repo>
```

## Process

For multi-repo cleanup requests ("clean up worktrees", "remove merged PR worktrees", "look across all repos"):

1. Run `wt_cleanup.py` (no flags = audit all repos with PR check).
2. Review the classification table with the user.
3. Bulk-remove `clean-merged` with `--execute clean-merged --yes`.
4. For `dirty-tooling-only`, confirm with the user; remove with `--execute clean-merged,dirty-tooling-only --yes`.
5. For `clean-stale`, ask before including in `--execute`.
6. For `dirty-real*`, `clean-no-pr`, `clean-open-pr` — go one-by-one with `wt_remove.py` after explicit user direction. Use `AskUserQuestion` so the user sees the diff and chooses.

For a single targeted removal:

1. Run a dry-run unless the user already gave explicit removal approval in the current turn.
2. Report the resolved worktree path, branch, dirty state, and the exact confirmed command.
3. If the worktree is dirty, ask before using `--force`.
4. Keep the branch by default. Delete a branch only when the user explicitly asks and the branch is not protected.
5. After confirmed removal, report what was removed and whether the branch was kept or deleted.

## Guardrails

- Do not remove a worktree with uncommitted real changes unless the user explicitly says to force remove it.
- Do not delete branches by default.
- Do not run `--execute` modes against unfamiliar classifications. Only `clean-merged`, `clean-stale`, and `dirty-tooling-only` are bulk-removable.
- If more than one worktree matches a name, ask the user to pick one.
- `--merged-to` only catches fast-forward merges. Use `wt_cleanup.py` (which calls `gh pr list`) to catch squash-merged PRs.
- When the audit shows a worktree with `dirty-real` files, prefer copying any salvageable artifacts into `context/work-items/<name>/` before discarding.
- Skill discovery: this skill owns both targeted removal AND bulk cleanup. Do not create a separate cleanup skill.
