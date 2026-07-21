---
name: worktree-sync
description: Sync a managed Workbench feature, hotfix, or review worktree with a target branch using canonical Python tooling. Use when the user asks to update a branch from develop/main, rebase, merge latest changes, or run wt-sync.
compatibility: macOS or Windows Workbench setup with Git and Python 3. Uses scripts/wt_sync.py, a symlink to the canonical Workbench script.
metadata:
  workbench.argument-hint: "[branch-or-worktree] [target-branch] [--repo name] [--merge|--rebase] [--stash] [--dry-run]"
---

# Sync Worktree

Sync a managed worktree with a target branch by rebase or merge.

Use the skill-local script symlink:

```bash
python3 scripts/wt_sync.py [branch-or-worktree] [target-branch] [--repo <repo>] [--merge|--rebase] [--stash] [--dry-run]
```

On Windows, use:

```powershell
py -3 scripts\wt_sync.py [branch-or-worktree] [target-branch] [--repo <repo>] [--merge|--rebase] [--stash] [--dry-run]
```

## Process

1. Default target is `develop`; pass `main` or another target when needed.
2. Default strategy is rebase; pass `--merge` when the user or repo policy prefers merge commits.
3. Run `--dry-run` first when dirty state or target branch is uncertain.
4. If the worktree is dirty, stop unless the user explicitly approves `--stash`.
5. Report `WORKTREE_PATH`, `BRANCH`, `TARGET`, `STRATEGY`, `DIRTY`, and whether the sync completed.

## Conflict Handling

If the script reports a conflict or failure:

1. Stop and report the worktree path.
2. Tell the user whether it was a rebase or merge.
3. Give the exact continuation command: `git rebase --continue`, `git rebase --abort`, `git commit`, or `git merge --abort` depending on the strategy.
4. Do not resolve conflicts unless the user asks.
