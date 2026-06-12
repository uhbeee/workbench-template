#!/usr/bin/env python3
"""Worktree-isolation guard for Claude Code (PreToolUse) and Codex (PostToolUse).

Enforces the AGENTS.md "Worktree Isolation" rule: don't edit a *managed* repo
(Workbench bare-repo + worktree layout, i.e. git common-dir basename ends in
``.git``) that is NOT the Workbench repo itself while it's on a protected branch
(develop/main/master/staging/production/release-*).

Two runtimes, two block protocols (auto-detected, or forced with --codex):
- **Claude Code** PreToolUse: blocks by exiting 2 with a stderr reason. Fires
  BEFORE the edit, so it truly prevents the write.
- **Codex** PostToolUse: Codex has no PreToolUse. Blocks by printing
  ``{"decision":"block","reason":...}`` to stdout (exit 0). Fires AFTER the
  write, so it can't pre-empt — but the block decision forces the agent to move
  the change into a worktree before continuing.

Target to check: the edited file's path (tool_input.file_path / notebook_path)
if present, else the payload ``cwd``, else the process cwd.

Fail-OPEN: any ambiguity/error -> allow. Disable with WB_HOOKS_DISABLED=1.
"""

import json
import os
import subprocess
import sys

PROTECTED = {"develop", "main", "master", "staging", "production"}
EXEMPT_REPOS = {"workbench"}


def _git(cwd: str, *args: str) -> str | None:
    try:
        out = subprocess.run(["git", "-C", cwd, *args],
                             capture_output=True, text=True, timeout=5)
        return out.stdout.strip() if out.returncode == 0 else None
    except Exception:
        return None


def _violation(start_dir: str) -> tuple[str, str] | None:
    """Return (repo, branch) if start_dir is a managed, non-exempt repo on a
    protected branch; else None."""
    d = start_dir if os.path.isdir(start_dir) else os.path.dirname(start_dir) or "."
    while d and not os.path.isdir(d):
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent
    common = _git(d, "rev-parse", "--git-common-dir")
    if not common:
        return None
    if not os.path.isabs(common):
        common = os.path.abspath(os.path.join(d, common))
    repo_dir = os.path.basename(common.rstrip("/"))
    if not repo_dir.endswith(".git") or repo_dir == ".git":
        return None
    repo = repo_dir[:-4]
    if repo in EXEMPT_REPOS:
        return None
    branch = _git(d, "rev-parse", "--abbrev-ref", "HEAD")
    if not branch:
        return None
    if branch in PROTECTED or branch.startswith("release/"):
        return (repo, branch)
    return None


def _reason(target_name: str, repo: str, branch: str) -> str:
    return (
        f"Worktree-isolation guard: `{target_name}` is in managed repo `{repo}` on "
        f"protected branch `{branch}`. Do NOT edit code on {branch} — create a feature "
        f"worktree first (worktree-feature-create skill, or "
        f"`git worktree add -b <branch> <path> {branch}`) and work there. "
        f"You can keep driving from {branch}; just don't write to it. "
        f"(Override this session with WB_HOOKS_DISABLED=1.)"
    )


def main() -> int:
    if os.environ.get("WB_HOOKS_DISABLED"):
        return 0
    codex = "--codex" in sys.argv[1:]
    session = "--session" in sys.argv[1:]
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    if not isinstance(data, dict):
        return 0

    ti = data.get("tool_input") or {}
    target = ti.get("file_path") or ti.get("notebook_path") or data.get("cwd") or os.getcwd()
    name = os.path.basename(target.rstrip("/")) or target

    hit = _violation(target)
    if not hit:
        return 0
    repo, branch = hit

    if session:
        # SessionStart heads-up (both runtimes): warn-only, never blocks the
        # session. stdout is surfaced as context by Claude; logged by Codex.
        print(
            f"Worktree-isolation: this session is in managed repo `{repo}` on protected "
            f"branch `{branch}`. Before editing code, create a feature worktree "
            f"(worktree-feature-create). Edits on {branch} will be blocked."
        )
        return 0

    reason = _reason(name, repo, branch)
    if codex:
        # Codex PostToolUse protocol: block via JSON on stdout, exit 0.
        print(json.dumps({"decision": "block", "reason": reason}))
        return 0
    # Claude Code PreToolUse protocol: block via exit 2 + stderr.
    sys.stderr.write(reason + "\n")
    return 2


if __name__ == "__main__":
    sys.exit(main())
