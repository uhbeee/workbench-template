---
name: worktree-migrate
description: Migrate or clone a repository into the managed Workbench bare-repo plus worktree layout using guarded dry-run first. Use when the user asks to add a repo to worktrees, migrate an existing clone, clone into worktree layout, or run wt-migrate.
compatibility: macOS or Windows Workbench setup with Git and Python 3. Uses scripts/wt_migrate.py, a symlink to the canonical Workbench script.
metadata:
  workbench.argument-hint: "--from-url <url>|--from-dir <path> [repo-name] [--confirm]"
---

# Migrate A Repo Into Worktrees

Use this skill to create a managed Workbench repo layout from an existing local clone or a remote URL.

## Safety Model

Migration creates new directories and may clone from remote. Agents should run the canonical script with `--dry-run` first and only omit `--dry-run` after explicit user approval.

## Commands

Dry-run from URL:

```bash
python3 scripts/wt_migrate.py --from-url <github-url> [repo-name] --dry-run
```

Confirmed migration:

```bash
python3 scripts/wt_migrate.py --from-url <github-url> [repo-name]
```

Windows Python launcher:

```bat
py -3 scripts\wt_migrate.py --from-url <github-url> [repo-name]
```

## Process

1. Run dry-run first unless the user explicitly approved migration in the current turn.
2. Report source, repo name, target base repo path, and the exact confirmed command.
3. Confirm the target path does not already exist.
4. On approval, rerun the same command without `--dry-run`.
5. Report the resulting `main`, `develop`, `_feature`, `_review`, and `_hotfix` layout when available.

## Guardrails

- Do not delete or modify the original repo when using `--from-dir`.
- Do not overwrite an existing `<repo>.git` base directory.
- Do not run confirmed migration without explicit approval.
