---
name: hotfix
description: Create managed hotfix worktrees and hotfix PRs using canonical Workbench worktree tooling. Use when the user asks for a hotfix branch/worktree, needs to cherry-pick or backport a merged PR to a release branch, needs a release-targeted hotfix PR, or asks for PPE/prod hotfix work while keeping develop/main clean.
compatibility: macOS or Windows Workbench setup with Git, GitHub CLI for PR cherry-picks, and Python 3. Uses scripts/wt_hotfix.py and scripts/wt_hotfix_pr.py from the skill-local scripts symlink.
metadata:
  workbench.argument-hint: "<branch-name>|<PR#> [base-branch] [--repo name] [--ticket JIRA-ID] [--release branch] [--dry-run] [--yes]"
---

# Hotfix

Create managed hotfix worktrees. This skill covers both plain hotfix branches and cherry-picking an already merged PR onto a release branch.

Plain hotfix branch/worktree:

```bash
python3 scripts/wt_hotfix.py <branch-name> [base-branch] --repo <repo> [--dry-run]
```

Cherry-pick/backport a merged PR to a release branch:

```bash
python3 scripts/wt_hotfix_pr.py <PR#> --repo <repo> [--ticket <JIRA-ID>] [--release <branch>] [--dry-run] [--yes]
```

On Windows, use:

```powershell
py -3 scripts\wt_hotfix.py <branch-name> [base-branch] --repo <repo> [--dry-run]
py -3 scripts\wt_hotfix_pr.py <PR#> --repo <repo> [--ticket <JIRA-ID>] [--release <branch>] [--dry-run] [--yes]
```

## Process

1. Decide whether this is a plain hotfix branch or a merged-PR backport.
2. If the user gave a PR number, PR URL, "cherry-pick", or "backport", use `wt_hotfix_pr.py`.
3. If the user gave a branch/name or says "create a hotfix worktree", use `wt_hotfix.py`.
4. If no repo is explicit, let the script infer it from the current worktree. If inference is uncertain, pass `--repo`.
5. Run `--dry-run` first when the base branch, release branch, or target environment is ambiguous.
6. Keep all edits inside the printed `_hotfix/` worktree path. Do not touch `develop`, `main`, or the base repo checkout.

For plain hotfixes:

1. Pass an explicit base branch when the hotfix should not branch from `develop` or the repo default branch.
2. Report `WORKTREE_PATH`, branch status, base branch, and dirty state.

For PR backports:

1. The script validates that the PR is merged, detects the merge strategy, selects or validates the release branch, infers a Jira ticket from the PR title/branch when possible, and prints the planned worktree and branch.
2. For actual execution, run without `--dry-run` and with `--yes` only after user intent is clear.
3. If cherry-pick conflicts occur, stop and report `WORKTREE_PATH` plus the conflicting files. Do not try to resolve conflicts unless the user asks.
4. On success, report `PR_URL`, `WORKTREE_PATH`, `HOTFIX_BRANCH`, and `CLEANUP_COMMAND`.

## Multiple Release Targets

When the user asks to hotfix both PPE and prod:

1. Identify the exact PPE and prod release branches. If the branches are not explicit, inspect `origin/release/*` and ask only if the target remains ambiguous.
2. Run the right hotfix script separately for each release branch.
3. Keep each hotfix in its own `_hotfix/` worktree and hotfix branch.
4. For plain hotfixes, use target-specific branch names such as `hotfix/<name>-ppe` and `hotfix/<name>-prod`.
5. For PR backports, report the PR URL, worktree path, and cleanup command for each target.
6. Do not cherry-pick or resolve conflicts from `develop`, `main`, or the base repo checkout.

## Notes

- This skill replaces the older split between `hotfix` and `worktree-hotfix-create`; use `hotfix` for both plain hotfix worktrees and PR backports.
- The script is non-interactive by default for agent use. It accepts `--quick` for compatibility with older aliases, but does not require postmortem prompts.
