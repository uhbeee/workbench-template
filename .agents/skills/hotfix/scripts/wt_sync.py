#!/usr/bin/env python3
"""Sync a managed worktree with a target branch."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

from common import (
    current_branch,
    fail,
    find_workbench_root,
    git_dirty_status,
    repo_from_args_or_cwd,
    resolve_managed_worktree,
    run,
    worktrees_root,
)


def resolve_sync_worktree(repo: Path, branch_or_name: str | None, cwd: Path) -> Path:
    if branch_or_name:
        resolved = resolve_managed_worktree(repo, branch_or_name, include_roots=True)
        if resolved:
            return resolved
        try:
            if current_branch(cwd) == branch_or_name:
                return cwd
        except subprocess.CalledProcessError:
            pass
        fail(f"could not find worktree for branch or name: {branch_or_name}")

    try:
        run(["git", "rev-parse", "--is-inside-work-tree"], cwd=cwd, capture=True)
    except subprocess.CalledProcessError:
        fail("not in a git worktree; pass a branch/worktree name")
    return cwd


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync a managed worktree with a target branch.")
    parser.add_argument("branch_or_worktree", nargs="?")
    parser.add_argument("target_branch", nargs="?", default="develop")
    parser.add_argument("--repo")
    parser.add_argument("--workdir")
    parser.add_argument("--merge", action="store_true")
    parser.add_argument("--rebase", action="store_true")
    parser.add_argument("--stash", action="store_true", help="Automatically stash dirty changes before syncing.")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    strategy = "merge" if args.merge else "rebase"
    if args.merge and args.rebase:
        fail("choose only one of --merge or --rebase")

    cwd = Path(args.workdir).expanduser().resolve() if args.workdir else Path.cwd().resolve()
    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    _, repo = repo_from_args_or_cwd(worktrees_root(workbench_root), args.repo, cwd)
    worktree_path = resolve_sync_worktree(repo, args.branch_or_worktree, cwd)

    try:
        branch = current_branch(worktree_path)
    except subprocess.CalledProcessError as exc:
        fail(f"could not determine current branch in {worktree_path}: {exc.returncode}")
    if branch == "HEAD":
        fail("HEAD is detached; checkout a branch before syncing")

    dirty = git_dirty_status(worktree_path)
    print(f"WORKTREE_PATH={worktree_path}", flush=True)
    print(f"BRANCH={branch}", flush=True)
    print(f"TARGET=origin/{args.target_branch}", flush=True)
    print(f"STRATEGY={strategy}", flush=True)
    print(f"DIRTY={'yes' if dirty else 'no'}", flush=True)
    if dirty:
        print(dirty, flush=True)

    if args.dry_run:
        print("DRY_RUN=1", flush=True)
        return 0

    if dirty and not args.stash:
        fail("worktree has uncommitted changes; commit, stash manually, or pass --stash")

    try:
        stashed = False
        if dirty and args.stash:
            run(["git", "stash", "push", "-m", "wt-sync: auto-stash before sync"], cwd=worktree_path)
            stashed = True

        run(["git", "fetch", "origin"], cwd=worktree_path)
        if run(
            ["git", "show-ref", "--verify", "--quiet", f"refs/remotes/origin/{args.target_branch}"],
            cwd=worktree_path,
            check=False,
        ).returncode != 0:
            fail(f"remote branch not found: origin/{args.target_branch}")

        if branch == args.target_branch:
            run(["git", "pull", "origin", args.target_branch], cwd=worktree_path)
        elif strategy == "rebase":
            run(["git", "rebase", f"origin/{args.target_branch}"], cwd=worktree_path)
        else:
            run(["git", "merge", f"origin/{args.target_branch}", "-m", f"Merge {args.target_branch} into {branch}"], cwd=worktree_path)

        if stashed:
            run(["git", "stash", "pop"], cwd=worktree_path)
        print("SYNCED=1", flush=True)
    except subprocess.CalledProcessError as exc:
        print("CONFLICT_OR_FAILURE=1", flush=True)
        fail(f"command failed with exit code {exc.returncode}: {' '.join(exc.cmd)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
