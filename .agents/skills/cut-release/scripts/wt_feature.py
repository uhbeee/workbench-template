#!/usr/bin/env python3
"""Create or locate a Workbench-managed feature worktree."""

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


def create_or_locate_feature_worktree(
    *,
    repo: Path,
    branch_name: str,
    base_branch: str | None,
    invoking_cwd: Path,
) -> Path:
    worktree_path = Path("_feature") / branch_leaf(branch_name)
    absolute_path = repo / worktree_path

    run(["git", "fetch", "origin"], cwd=repo)

    if absolute_path.exists():
        print("Feature worktree already exists", flush=True)
        return absolute_path

    invoking_worktree = git_toplevel(invoking_cwd)

    if git_ref_exists(repo, f"refs/heads/{branch_name}"):
        print(f"Creating feature worktree from local branch {branch_name}", flush=True)
        run(["git", "worktree", "add", str(worktree_path), branch_name], cwd=repo)
        sync_config_to_worktree(repo, worktree_path, invoking_worktree)
        return absolute_path

    if git_ref_exists(repo, f"refs/remotes/origin/{branch_name}"):
        print(f"Creating feature worktree from remote branch origin/{branch_name}", flush=True)
        run(
            ["git", "worktree", "add", "--track", "-b", branch_name, str(worktree_path), f"origin/{branch_name}"],
            cwd=repo,
        )
        sync_config_to_worktree(repo, worktree_path, invoking_worktree)
        return absolute_path

    selected_base = choose_base_branch(repo, base_branch)
    base_ref = resolve_base_ref(repo, selected_base)
    print(f"Creating feature worktree {branch_name} from {selected_base}", flush=True)
    run(["git", "worktree", "add", "-b", branch_name, str(worktree_path), base_ref], cwd=repo)
    sync_config_to_worktree(repo, worktree_path, invoking_worktree)

    run(
        ["git", "branch", "--set-upstream-to", f"origin/{selected_base}", branch_name],
        cwd=absolute_path,
        check=False,
    )
    return absolute_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Create or locate a Workbench-managed feature worktree.")
    parser.add_argument("branch_name")
    parser.add_argument("base_branch", nargs="?")
    parser.add_argument("--repo", dest="repo_name")
    parser.add_argument("--workdir", default=None, help="Original invoking directory for wrapper scripts.")
    args = parser.parse_args()

    invoking_cwd = Path(args.workdir).expanduser().resolve() if args.workdir else Path.cwd().resolve()
    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    _, base_repo = repo_from_args_or_cwd(worktrees_root(workbench_root), args.repo_name, invoking_cwd)

    try:
        worktree_path = create_or_locate_feature_worktree(
            repo=base_repo,
            branch_name=args.branch_name,
            base_branch=args.base_branch,
            invoking_cwd=invoking_cwd,
        )
    except subprocess.CalledProcessError as exc:
        fail(f"command failed with exit code {exc.returncode}: {' '.join(exc.cmd)}")

    print(f"WORKTREE_PATH={worktree_path}", flush=True)
    print_short_status(worktree_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
