---
name: cut-release
description: Create a release branch and managed _release worktree in a Workbench repo using canonical Python worktree tooling. Use when the user wants to cut a release, create a release branch, start a release process, preview the next release branch name, or keep release work out of main/develop.
compatibility: macOS or Windows Workbench setup with Git and Python 3. Uses scripts/wt_release.py, a symlink to the canonical Workbench script.
metadata:
  workbench.argument-hint: "[prefix] [--repo name] [--source branch] [--date date] [--dry-run] [--yes]"
---

# Cut Release

Create and optionally push a release branch in a managed Workbench repo, then create a `_release/` worktree for any release follow-up work. Do not cut releases by editing `develop`, `main`, or the base repo directly.

Use the skill-local script symlink:

```bash
python3 scripts/wt_release.py [prefix] --repo <repo> [--source <branch>] [--date <date>] [--dry-run] [--yes]
```

On Windows, use:

```powershell
py -3 scripts\wt_release.py [prefix] --repo <repo> [--source <branch>] [--date <date>] [--dry-run] [--yes]
```

## Process

1. Parse the user's arguments: optional release prefix, `--repo`, `--source`, `--date`, `--dry-run`, and `--yes`.
2. If no repo is explicit, let the script infer it from the current worktree. If inference is unlikely, pass `--repo`.
3. Run a dry run first when the user asks "what would happen", when the repo/release pattern is unclear, or before creating a release from an unfamiliar repo.
4. If the repo has multiple release prefixes and the user did not provide one, report the available prefixes and ask which one to use.
5. For actual creation, run the same command without `--dry-run`; pass `--yes` only when the user has clearly asked to create the release branch.
6. Report `BRANCH`, `SOURCE`, `SOURCE_SHA`, `WORKTREE_PATH`, whether it was pushed, and any patch suffix the script selected.
7. Use the printed `WORKTREE_PATH` for release notes, version bumps, cherry-pick verification, or any follow-up release edits.

## Notes

- The script discovers the release date format from existing `origin/release/*` branches.
- Date formats currently handled: `YYYY.MM.DD`, `YYYY-MM-DD`, `MM-DD-YY`, and `MM-DD-YYYY`.
- If today's `YYYY.MM.DD` branch already exists, the script auto-selects the next `.N` suffix.
- The skill should not hand-roll release branch names when the script can infer them.
- Release worktrees live under `_release/<release-name-with-slashes-replaced>`.
