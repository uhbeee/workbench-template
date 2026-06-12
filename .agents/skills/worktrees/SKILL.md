---
name: worktrees
description: Show, inspect, resolve, or list git worktrees across managed Workbench repos using canonical Python worktree tooling. Use when the user asks about worktree status, active branches, dirty worktrees, available repo checkouts, where a worktree is, which worktree an agent should use, or asks to go/find/pick/navigate to a worktree.
compatibility: macOS or Windows Workbench setup with Git and Python 3. Uses scripts/wt_status.py and scripts/wt_resolve.py from the skill-local scripts symlink.
metadata:
  workbench.argument-hint: "[repo-name] [--name worktree] [--kind feature|hotfix|review|release|root] [--list]"
---

# Worktrees

Use this skill to inspect or resolve managed Workbench worktrees. It is read-only and should not create, remove, clean, or switch worktrees.

## Commands

Status overview:

```bash
python3 scripts/wt_status.py [repo-name]
```

Resolve or list worktree paths:

```bash
python3 scripts/wt_resolve.py [--repo <repo>] [--name <worktree>] [--kind feature|hotfix|review|release|root] [--list]
```

On Windows, use the active Python launcher if `python3` is not available:

```bat
py -3 scripts\wt_status.py [repo-name]
py -3 scripts\wt_resolve.py [--repo <repo>] [--name <worktree>] [--kind feature|hotfix|review|release|root] [--list]
```

For human terminal use, the shell alias is still supported:

```bash
wt-status [repo-name]
```

If the function is not loaded in the current non-interactive shell, run the canonical Python command directly.

```bash
python3 scripts/wt_status.py [repo-name]
```

```bat
py -3 scripts\wt_status.py [repo-name]
```

## Process

1. Read `config.yaml` from the Workbench root to get `worktrees.root`.
2. If the user asks for status, active branches, dirty worktrees, or available checkouts, run `scripts/wt_status.py`.
3. If the user asks to find, go to, pick, navigate to, or use a specific worktree, run `scripts/wt_resolve.py`.
4. If the user named a repo, pass that repo name.
5. If the user gave partial text, pass it as `--name`; the resolver accepts a unique fuzzy match.
6. For status, summarize:
   - repo name,
   - worktree path,
   - branch,
   - dirty/clean status,
   - ahead/behind status when shown by the script.
7. For path resolution, read the printed `WORKTREE_PATH=<absolute-path>` line and use that path as the working directory for later commands.
8. If multiple matches are printed, ask the user which one they want.
9. If the user needs to create a worktree next, hand off to the `worktree-feature-create` skill.

## Examples

```bash
python3 scripts/wt_status.py recruit-api
python3 scripts/wt_resolve.py --repo recruit-api --name mcp-calls-recruit-api-for-everything
python3 scripts/wt_resolve.py --repo example-service --kind feature --list
python3 scripts/wt_resolve.py --name develop
```

## Guardrails

- Do not run cleanup or removal commands from this skill.
- Do not assume `main` or `develop` is safe for code changes. Use `worktree-feature-create` before implementation work.
- If the script reports no matching repo, verify the expected base path under `/Users/joshuapalamuttam/Developer/worktrees/<repo>.git` before concluding the repo is unavailable.
- If the user wants interactive shell navigation in their own terminal, tell them to use `wtn`; for agent work, use the printed `WORKTREE_PATH`.
