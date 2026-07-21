#!/usr/bin/env python3
"""Show Workbench-managed worktree status."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

from common import fail, find_workbench_root, output, worktrees_root


def iter_repos(root: Path, repo_filter: str | None) -> list[Path]:
    if repo_filter:
        repo = root / f"{repo_filter.removesuffix('.git')}.git"
        if not repo.is_dir():
            fail(f"repo not found: {repo}")
        return [repo]
    return sorted(path for path in root.glob("*.git") if path.is_dir())


def worktree_entries(repo: Path) -> list[tuple[str, str, Path]]:
    entries: list[tuple[str, str, Path]] = []
    current_path: Path | None = None
    for raw_line in output(["git", "worktree", "list", "--porcelain"], cwd=repo).splitlines():
        if raw_line.startswith("worktree "):
            current_path = Path(raw_line.removeprefix("worktree "))
        elif raw_line.startswith("branch ") and current_path:
            branch = raw_line.removeprefix("branch refs/heads/")
            entries.append((current_path.name, branch, current_path))
            current_path = None
    return entries


def change_count(path: Path) -> int:
    try:
        status = output(["git", "status", "--porcelain"], cwd=path)
    except subprocess.CalledProcessError:
        return 0
    return len([line for line in status.splitlines() if line.strip()])


def ahead_behind(path: Path) -> tuple[int, int]:
    raw = output(["git", "rev-list", "--left-right", "--count", "HEAD...@{upstream}"], cwd=path, check=False)
    parts = raw.split()
    if len(parts) != 2:
        return 0, 0
    try:
        return int(parts[0]), int(parts[1])
    except ValueError:
        return 0, 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Show managed Workbench worktree status.")
    parser.add_argument("repo_name", nargs="?")
    parser.add_argument("--dirty", action="store_true")
    args = parser.parse_args()

    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    root = worktrees_root(workbench_root)

    print()
    print("Worktree Status")
    print("===============")
    print()

    for repo in iter_repos(root, args.repo_name):
        repo_name = repo.name.removesuffix(".git")
        rows = []
        for name, branch, path in worktree_entries(repo):
            changes = change_count(path)
            if args.dirty and changes == 0:
                continue
            ahead, behind = ahead_behind(path)
            status = f"{changes} changes" if changes else "clean"
            sync = ""
            if ahead:
                sync += f" +{ahead}"
            if behind:
                sync += f" -{behind}"
            rows.append((name, branch, status, sync))

        if args.dirty and not rows:
            continue

        print(repo_name)
        print("-" * len(repo_name))
        for name, branch, status, sync in rows:
            print(f"  {name:<28} {branch:<40} {status}{sync}")
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
