#!/usr/bin/env python3
"""Create or locate a Workbench-managed hotfix worktree."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

from common import (
    branch_leaf,
    detect_default_branch,
    fail,
    find_workbench_root,
    git_ref_exists,
    git_toplevel,
    print_short_status,
    repo_from_args_or_cwd,
    resolve_base_ref,
    run,
    sync_config_to_worktree,
    worktrees_root,
)


def choose_base_branch(repo: Path, explicit_base: str | None) -> str:
    if explicit_base:
        return explicit_base
    if git_ref_exists(repo, "refs/remotes/origin/develop") or git_ref_exists(repo, "refs/heads/develop"):
        return "develop"
    default = detect_default_branch(repo)
    if default:
        return default
    fail("no develop/main/master found; specify a base branch")


def normalize_hotfix_branch(name: str) -> tuple[str, Path]:
    branch_name = name if name.startswith("hotfix/") else f"hotfix/{name}"
    return branch_name, Path("_hotfix") / branch_leaf(branch_name)


def create_or_locate_hotfix_worktree(
    *,
    repo: Path,
    name: str,
    base_branch: str | None,
    invoking_cwd: Path,
    dry_run: bool,
) -> Path:
    branch_name, worktree_relative = normalize_hotfix_branch(name)
    worktree_path = repo / worktree_relative

    run(["git", "fetch", "origin"], cwd=repo)

    if worktree_path.exists():
        print("Hotfix worktree already exists", flush=True)
        return worktree_path

    if dry_run:
        selected_base = choose_base_branch(repo, base_branch)
        print(f"HOTFIX_BRANCH={branch_name}", flush=True)
        print(f"BASE={selected_base}", flush=True)
        print(f"WORKTREE_PATH={worktree_path}", flush=True)
        print("DRY_RUN=1", flush=True)
        return worktree_path

    invoking_worktree = git_toplevel(invoking_cwd)

    if git_ref_exists(repo, f"refs/heads/{branch_name}"):
        print(f"Creating hotfix worktree from local branch {branch_name}", flush=True)
        run(["git", "worktree", "add", str(worktree_relative), branch_name], cwd=repo)
        sync_config_to_worktree(repo, worktree_relative, invoking_worktree)
        return worktree_path

    if git_ref_exists(repo, f"refs/remotes/origin/{branch_name}"):
        print(f"Creating hotfix worktree from remote branch origin/{branch_name}", flush=True)
        run(
            ["git", "worktree", "add", "--track", "-b", branch_name, str(worktree_relative), f"origin/{branch_name}"],
            cwd=repo,
        )
        sync_config_to_worktree(repo, worktree_relative, invoking_worktree)
        return worktree_path

    selected_base = choose_base_branch(repo, base_branch)
    base_ref = resolve_base_ref(repo, selected_base)
    print(f"Creating hotfix worktree {branch_name} from {selected_base}", flush=True)
    (repo / "_hotfix").mkdir(exist_ok=True)
    run(["git", "worktree", "add", "-b", branch_name, str(worktree_relative), base_ref], cwd=repo)
    sync_config_to_worktree(repo, worktree_relative, invoking_worktree)
    return worktree_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Create or locate a Workbench-managed hotfix worktree.")
    parser.add_argument("branch_name")
    parser.add_argument("base_branch", nargs="?")
    parser.add_argument("--repo", dest="repo_name")
    parser.add_argument("--workdir")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    invoking_cwd = Path(args.workdir).expanduser().resolve() if args.workdir else Path.cwd().resolve()
    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    _, base_repo = repo_from_args_or_cwd(worktrees_root(workbench_root), args.repo_name, invoking_cwd)

    try:
        worktree_path = create_or_locate_hotfix_worktree(
            repo=base_repo,
            name=args.branch_name,
            base_branch=args.base_branch,
            invoking_cwd=invoking_cwd,
            dry_run=args.dry_run,
        )
    except subprocess.CalledProcessError as exc:
        fail(f"command failed with exit code {exc.returncode}: {' '.join(exc.cmd)}")

    if not args.dry_run:
        print(f"WORKTREE_PATH={worktree_path}", flush=True)
        print_short_status(worktree_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
