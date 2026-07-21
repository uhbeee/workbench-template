#!/usr/bin/env python3
"""Clone or migrate a repository into Workbench worktree layout."""

from __future__ import annotations

import argparse
import os
import subprocess
from pathlib import Path

from common import fail, find_workbench_root, git_ref_exists, run, worktrees_root


def repo_name_from_source(source: str) -> str:
    normalized = source.rstrip("/").removesuffix(".git")
    return Path(normalized).name


def convert_to_ssh(url: str) -> str:
    if url.startswith("https://github.com/"):
        return "git@github.com:" + url.removeprefix("https://github.com/")
    return url


def ensure_git_url(url: str) -> str:
    return url if url.endswith(".git") else f"{url}.git"


def patch_entire_hooks_for_windows(bare_repo: Path) -> None:
    if os.name != "nt":
        return
    hook_file = bare_repo / "hooks" / "post-commit"
    if not hook_file.is_file():
        return
    content = hook_file.read_text(encoding="utf-8", errors="ignore")
    if "entire hooks git post-commit" not in content or "git-common-dir" in content:
        return
    hook_file.write_text(
        """#!/bin/sh
# Entire CLI hooks
# Post-commit hook: condense session data if commit has Entire-Checkpoint trailer

# Workaround: Entire's go-git fails to rename over read-only loose objects on Windows.
git_dir=$(git rev-parse --git-common-dir 2>/dev/null)
if [ -n "$git_dir" ] && [ -d "$git_dir/objects" ]; then
    find "$git_dir/objects" -maxdepth 2 -type f ! -path "*/pack/*.pack" ! -path "*/pack/*.idx" ! -path "*/pack/*.rev" -exec chmod u+w {} + 2>/dev/null
fi

entire hooks git post-commit 2>/dev/null || true
""",
        encoding="utf-8",
    )


def create_worktrees(bare_repo: Path) -> None:
    if git_ref_exists(bare_repo, "refs/remotes/origin/main"):
        print("Creating main worktree")
        if git_ref_exists(bare_repo, "refs/heads/main"):
            run(["git", "worktree", "add", "main", "main"], cwd=bare_repo)
        else:
            run(["git", "worktree", "add", "--track", "-b", "main", "main", "origin/main"], cwd=bare_repo)
        run(["git", "-C", "main", "branch", "--set-upstream-to=origin/main", "main"], cwd=bare_repo, check=False)
    elif git_ref_exists(bare_repo, "refs/remotes/origin/master"):
        print("Creating main worktree from origin/master")
        if git_ref_exists(bare_repo, "refs/heads/main"):
            run(["git", "worktree", "add", "main", "main"], cwd=bare_repo)
        else:
            run(["git", "worktree", "add", "--track", "-b", "main", "main", "origin/master"], cwd=bare_repo)
        run(["git", "-C", "main", "branch", "--set-upstream-to=origin/master", "main"], cwd=bare_repo, check=False)
    else:
        print("warning: no main/master branch found")

    if git_ref_exists(bare_repo, "refs/remotes/origin/develop"):
        print("Creating develop worktree")
        if git_ref_exists(bare_repo, "refs/heads/develop"):
            run(["git", "worktree", "add", "develop", "develop"], cwd=bare_repo)
        else:
            run(["git", "worktree", "add", "--track", "-b", "develop", "develop", "origin/develop"], cwd=bare_repo)
        run(["git", "-C", "develop", "branch", "--set-upstream-to=origin/develop", "develop"], cwd=bare_repo, check=False)

    for dirname in ("_feature", "_review", "_hotfix"):
        (bare_repo / dirname).mkdir(exist_ok=True)


def migrate_from_url(
    root: Path,
    url: str,
    repo_name: str,
    dry_run: bool,
    *,
    source_mode: str = "--from-url",
    source_display: str | None = None,
) -> Path:
    normalized_url = convert_to_ssh(ensure_git_url(url))
    target = root / f"{repo_name.removesuffix('.git')}.git"

    print(f"SOURCE_MODE={source_mode}")
    print(f"SOURCE={source_display or url}")
    print(f"REPO_NAME={repo_name}")
    print(f"TARGET_BASE_REPO={target}")

    if target.exists():
        fail(f"target already exists: {target}")

    if dry_run:
        print("DRY_RUN=1")
        print(f"COMMAND=git clone --bare {normalized_url} {target}")
        return target

    root.mkdir(parents=True, exist_ok=True)
    run(["git", "clone", "--bare", normalized_url, str(target)])
    patch_entire_hooks_for_windows(target)
    run(["git", "config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*"], cwd=target)
    run(["git", "fetch", "origin"], cwd=target)
    create_worktrees(target)
    print(f"MIGRATED={target}")
    run(["git", "worktree", "list"], cwd=target)
    return target


def migrate_from_dir(root: Path, source_dir: Path, repo_name: str, dry_run: bool) -> Path:
    if not source_dir.is_dir():
        fail(f"source directory not found: {source_dir}")
    if not (source_dir / ".git").exists():
        fail(f"not a git repository: {source_dir}")
    remote_url = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        cwd=str(source_dir),
        text=True,
        capture_output=True,
        check=False,
    ).stdout.strip()
    if not remote_url:
        fail("source repo has no origin remote")

    return migrate_from_url(
        root,
        remote_url,
        repo_name,
        dry_run,
        source_mode="--from-dir",
        source_display=str(source_dir),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Migrate a repo into Workbench worktree layout.")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--from-url")
    source.add_argument("--from-dir")
    parser.add_argument("repo_name", nargs="?")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    root = worktrees_root(workbench_root)

    if args.from_url:
        repo_name = args.repo_name or repo_name_from_source(args.from_url)
        migrate_from_url(root, args.from_url, repo_name, args.dry_run)
    else:
        source_dir = Path(args.from_dir).expanduser().resolve()
        repo_name = args.repo_name or source_dir.name
        migrate_from_dir(root, source_dir, repo_name, args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
