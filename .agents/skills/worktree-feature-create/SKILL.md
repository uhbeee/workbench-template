---
name: worktree-feature-create
description: Create or enter a feature worktree in a managed local repo using the canonical Python worktree tooling. Use this before doing implementation work in any managed repo, when the user asks for a feature branch/worktree, when an agent-flow PR slice needs a repo checkout, or when changes were accidentally made on main/develop and need to be moved into a proper feature worktree before continuing.
compatibility: macOS or Windows Workbench setup with Git and Python 3. Uses scripts/wt_feature.py, a symlink to the canonical Workbench script.
metadata:
  workbench.argument-hint: "<branch-name> [base-branch] [--repo name]"
---

# Create A Feature Worktree

Use this skill to create or enter a feature worktree for a managed repository. The workflow is intentionally routed through Workbench's canonical Python implementation, so branch naming, folder layout, config sync, and upstream setup stay consistent across macOS, Windows, aliases, and agents.

## Required Rule

For repo implementation work, use the skill-local script symlink:

```bash
python3 scripts/wt_feature.py --repo <repo> <branch-name> [base-branch]
```

On Windows, use the active Python launcher if `python3` is not available:

```bat
py -3 scripts\wt_feature.py --repo <repo> <branch-name> [base-branch]
```

The script resolves the target repo internally and prints `WORKTREE_PATH=<absolute-path>`; enter that path before editing code.

For human terminal use, the `wt-feature` alias is still supported.

macOS:

```bash
cd /Users/joshuapalamuttam/Developer/worktrees/<repo>.git
wt-feature <branch-name> [base-branch]
```

Windows:

```bat
cd /d C:\worktrees\<repo>.git
wt-feature <branch-name> [base-branch]
```

If the `wt-feature` shell function or command is not loaded in the current non-interactive shell, use the canonical Python command directly.

```bash
python3 scripts/wt_feature.py --repo <repo> <branch-name> [base-branch]
```

```bat
py -3 scripts\wt_feature.py --repo <repo> <branch-name> [base-branch]
```

Prefer the canonical Python command. Do not hand-roll `git worktree add` when the canonical tooling is present and working.

## Non-Workbench Fallback (no canonical tooling present)

This skill must still create a worktree on a machine that does **not** have the Workbench setup — i.e. when `scripts/wt_feature.py` / the `wt-feature` alias is absent OR there is no `config.yaml` (so `worktrees.root` can't be resolved). In that case, **fall back to plain git automatically — no user approval needed** (there is no canonical tool to defer to):

```bash
# from inside the target repo's working copy
base="${2:-$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || echo main)}"   # prefer develop if it exists
git show-ref --verify --quiet refs/heads/develop && base=develop
git fetch --quiet origin "$base" 2>/dev/null || true
wt_path="../$(basename "$PWD")-wt/$1"      # sibling dir; adjust if the repo layout differs
git worktree add -b "$1" "$wt_path" "$base"
echo "WORKTREE_PATH=$(cd "$wt_path" && pwd)"
```

Print the same `WORKTREE_PATH=<abs>` line so callers parse it identically to the canonical path. Cleanup in this mode is `git worktree remove <path>` + `git branch -d <branch>` (mirrors what `worktree-remove` does with tooling).

## Inputs

Accept:

- `<branch-name>`: required unless the user gave a PR slice or feature name that clearly implies one.
- `[base-branch]`: optional. If omitted, the script prefers `develop` when present and otherwise falls back to the repo default branch.
- `--repo <name>`: optional. Use when the current directory is not already inside the target repo.

Examples:

```bash
python3 scripts/wt_feature.py --repo example-service runtime-pass-through-contract develop
python3 scripts/wt_feature.py --repo recruit-api mcp-calls-recruit-api-for-everything develop
python3 scripts/wt_feature.py --repo backend RUN-1234-search-fix main
```

## Process

1. Read `config.yaml` from the Workbench root to get `worktrees.root`.
2. Determine the repo:
   - If `--repo <name>` is provided, use that.
   - If currently inside a managed repo, derive the repo from `git rev-parse --git-common-dir`.
   - If neither is clear, ask the user which repo to use.
3. Run `python3 scripts/wt_feature.py --repo <repo> <branch-name> [base-branch]` from the skill root. On Windows, use `py -3` or `python` if that is the configured launcher.
4. Read the printed `WORKTREE_PATH=<absolute-path>` line.
5. Enter that path.
6. Run `git status --short --branch` if the script output did not already show the status you need.
7. Report the worktree path, branch, base branch if known, and any dirty state.

## Branch Leaf

The script stores feature worktrees under `_feature/<branch-leaf>`, where `<branch-leaf>` is the final path segment of the branch name. For example:

```text
feature/runtime-pass-through-contract -> _feature/runtime-pass-through-contract
RUN-1234-search-fix -> _feature/RUN-1234-search-fix
```

## Implementation Guardrails

- Do code-changing work in the feature worktree, not in the repo base directory, `main`, or `develop`, unless the user explicitly asks for that.
- For stacked PRs, create the dependent worktree from the previous PR branch and record that dependency in the plan or PR breakdown.
- For parallel PR slices, create separate feature worktrees from the same approved base branch.
- Preserve dirty user changes. If the selected worktree is dirty before your edits, inspect and work around them rather than reverting.
- If the worktree already exists, use the printed path and continue there after checking status.

## Dirty Main/Develop Rescue

When the user says something like "take what was done in develop accidentally and make a worktree out of it":

1. Inspect the dirty source checkout with `git status --short --branch`.
2. Confirm the source branch (`develop`, `main`, or another base branch) and choose a feature branch name.
3. Create the feature worktree from that source branch with `scripts/wt_feature.py`.
4. Move the uncommitted work into the feature worktree using a patch/stash/copy flow that preserves staged changes and untracked files.
5. Verify the feature worktree has the intended diff before making more edits there.
6. Do not clean the original `develop` or `main` checkout until the user approves cleanup after verification.
