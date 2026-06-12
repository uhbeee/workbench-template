#!/usr/bin/env python3
"""Remove a Workbench hotfix worktree after merge."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

from common import fail, find_workbench_root, repo_from_args_or_cwd, run, worktrees_root


def main() -> int:
    parser = argparse.ArgumentParser(description="Remove a managed hotfix worktree.")
    parser.add_argument("name")
    parser.add_argument("--repo")
    parser.add_argument("--workdir")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    cwd = Path(args.workdir).expanduser().resolve() if args.workdir else Path.cwd().resolve()
    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    _, repo = repo_from_args_or_cwd(worktrees_root(workbench_root), args.repo, cwd)
    name = args.name.removeprefix("_hotfix/").removeprefix("hotfix/")
    target = repo / "_hotfix" / name

    if not target.exists():
        fail(f"hotfix worktree not found: {target}")

    print(f"WORKTREE_PATH={target}", flush=True)
    print(f"COMMAND=git worktree remove _hotfix/{name} --force", flush=True)
    if args.dry_run:
        print("DRY_RUN=1", flush=True)
        return 0

    try:
        run(["git", "worktree", "remove", f"_hotfix/{name}", "--force"], cwd=repo)
        run(["git", "worktree", "prune"], cwd=repo)
    except subprocess.CalledProcessError as exc:
        fail(f"command failed with exit code {exc.returncode}: {' '.join(exc.cmd)}")
    print(f"REMOVED=_hotfix/{name}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
