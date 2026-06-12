#!/usr/bin/env python3
"""Resolve managed Workbench worktree paths."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path

from common import fail, find_workbench_root, git_branch, worktrees_root


@dataclass
class Worktree:
    repo: str
    name: str
    kind: str
    path: str
    branch: str


def list_repo_worktrees(repo_path: Path) -> list[Worktree]:
    repo = repo_path.name.removesuffix(".git")
    entries: list[Worktree] = []

    for root_name in ("main", "develop", "master"):
        path = repo_path / root_name
        if path.is_dir():
            entries.append(Worktree(repo, root_name, "root", str(path), git_branch(path)))

    for kind_dir, kind in (("_feature", "feature"), ("_hotfix", "hotfix"), ("_review", "review")):
        parent = repo_path / kind_dir
        if parent.is_dir():
            entries.extend(
                Worktree(repo, path.name, kind, str(path), git_branch(path))
                for path in sorted(child for child in parent.iterdir() if child.is_dir())
            )

    return entries


def all_worktrees(root: Path, repo: str | None) -> list[Worktree]:
    if repo:
        repo_path = root / f"{repo.removesuffix('.git')}.git"
        if not repo_path.is_dir():
            fail(f"repo not found: {repo_path}")
        return list_repo_worktrees(repo_path)

    entries: list[Worktree] = []
    for repo_path in sorted(root.glob("*.git")):
        if repo_path.is_dir():
            entries.extend(list_repo_worktrees(repo_path))
    return entries


def print_entries(entries: list[Worktree], *, as_json: bool) -> None:
    if as_json:
        print(json.dumps([asdict(entry) for entry in entries], indent=2))
        return

    for entry in entries:
        branch = f" branch={entry.branch}" if entry.branch else ""
        print(f"{entry.repo}\t{entry.kind}\t{entry.name}\t{entry.path}{branch}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Resolve a managed Workbench worktree path.")
    parser.add_argument("--repo")
    parser.add_argument("--name")
    parser.add_argument("--kind", choices=["root", "feature", "hotfix", "review"])
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    entries = all_worktrees(worktrees_root(workbench_root), args.repo)

    if args.kind:
        entries = [entry for entry in entries if entry.kind == args.kind]

    if args.list or not args.name:
        print_entries(entries, as_json=args.json)
        return 0

    needle = args.name.lower()
    exact = [entry for entry in entries if entry.name.lower() == needle or entry.path.lower().endswith(f"/{needle}")]
    matches = exact or [entry for entry in entries if needle in entry.name.lower() or needle in entry.path.lower()]

    if not matches:
        fail(f"no worktree matched: {args.name}")
    if len(matches) > 1:
        print("Multiple worktrees matched:")
        print_entries(matches, as_json=False)
        fail("refine --repo, --name, or --kind")

    selected = matches[0]
    print(f"WORKTREE_PATH={selected.path}")
    print(f"REPO={selected.repo}")
    print(f"WORKTREE_NAME={selected.name}")
    print(f"WORKTREE_KIND={selected.kind}")
    if selected.branch:
        print(f"BRANCH={selected.branch}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
