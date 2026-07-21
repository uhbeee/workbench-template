#!/usr/bin/env python3
"""Remove the current Workbench review worktree."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

from common import fail, find_workbench_root, repo_from_args_or_cwd, run, worktrees_root


def main() -> int:
    parser = argparse.ArgumentParser(description="Remove _review/current from a managed repo.")
    parser.add_argument("--repo")
    parser.add_argument("--workdir")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    cwd = Path(args.workdir).expanduser().resolve() if args.workdir else Path.cwd().resolve()
    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    _, repo = repo_from_args_or_cwd(worktrees_root(workbench_root), args.repo, cwd)
    target = repo / "_review" / "current"

    if not target.exists():
        print("No current review worktree found.", flush=True)
        return 0

    print(f"WORKTREE_PATH={target}", flush=True)
    print("COMMAND=git worktree remove _review/current --force", flush=True)
    if args.dry_run:
        print("DRY_RUN=1", flush=True)
        return 0

    try:
        run(["git", "worktree", "remove", "_review/current", "--force"], cwd=repo)
        run(["git", "worktree", "prune"], cwd=repo)
    except subprocess.CalledProcessError as exc:
        fail(f"command failed with exit code {exc.returncode}: {' '.join(exc.cmd)}")
    print("REMOVED=_review/current", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
