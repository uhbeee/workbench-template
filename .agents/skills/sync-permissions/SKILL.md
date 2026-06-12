---
name: sync-permissions
description: Scan worktree permissions and promote selected Claude Code permissions to global settings using canonical Python tooling. Use when the user wants to sync, promote, consolidate, or inspect permissions across Workbench worktrees.
compatibility: macOS or Windows Workbench setup with Python 3. Uses scripts/wt_sync_permissions.py, a symlink to the canonical Workbench script.
metadata:
  workbench.argument-hint: "[--all] [--dry-run] [--apply-all]"
---

# Sync Worktree Permissions

Scan `.claude/settings.local.json` across worktrees and promote missing permissions to `~/.claude/settings.local.json`.

Use the skill-local script symlink:

```bash
python3 scripts/wt_sync_permissions.py [--all] [--dry-run] [--apply-all]
```

On Windows, use:

```powershell
py -3 scripts\wt_sync_permissions.py [--all] [--dry-run] [--apply-all]
```

## Process

1. Use `--all` if the user wants every managed repo scanned. Otherwise run from the relevant repo/worktree.
2. Run `--dry-run` first to show missing permissions without editing global settings.
3. If the user approves adding all listed permissions, re-run with `--apply-all`.
4. Report `SCANNED_FILES`, `MISSING_PERMISSIONS`, each `PERMISSION=...`, and `ADDED`.

## Guardrails

- Do not promote permissions silently. Use `--apply-all` only after explicit user approval.
- This changes global Claude Code settings, so summarize exactly what was added.
- If the user only wants to inspect permissions, stop after `--dry-run`.
