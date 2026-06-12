#!/usr/bin/env python3
"""Create or refresh a Workbench-managed PR review worktree."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
from pathlib import Path

from common import (
    fail,
    find_workbench_root,
    git_toplevel,
    print_short_status,
    repo_from_args_or_cwd,
    run,
    sync_config_to_worktree,
    worktrees_root,
)


def normalize_pr_input(value: str) -> str:
    match = re.search(r"github\.com/.+/pull/([0-9]+)", value)
    return match.group(1) if match else value


def fetch_pr_or_branch(repo: Path, pr_input: str, *, dry_run: bool) -> str:
    if re.fullmatch(r"[0-9]+", pr_input):
        branch_name = f"pr-{pr_input}"
        print(f"Fetching PR #{pr_input}", flush=True)

        pr_branch = ""
        if shutil.which("gh"):
            pr_branch = subprocess.run(
                ["gh", "pr", "view", pr_input, "--json", "headRefName", "-q", ".headRefName"],
                cwd=str(repo),
                text=True,
                capture_output=True,
                check=False,
            ).stdout.strip()

        if dry_run:
            return branch_name

        run(["git", "fetch", "origin"], cwd=repo)
        if pr_branch:
            run(["git", "fetch", "origin", f"{pr_branch}:{branch_name}"], cwd=repo)
        else:
            run(["git", "fetch", "origin", f"pull/{pr_input}/head:{branch_name}"], cwd=repo)
        return branch_name

    branch_name = pr_input
    if run(["git", "show-ref", "--verify", "--quiet", f"refs/remotes/origin/{branch_name}"], cwd=repo, check=False).returncode != 0:
        run(["git", "fetch", "origin"], cwd=repo)
    if run(["git", "show-ref", "--verify", "--quiet", f"refs/remotes/origin/{branch_name}"], cwd=repo, check=False).returncode != 0:
        fail(f"branch not found on remote: {branch_name}")
    if dry_run:
        return branch_name
    run(["git", "fetch", "origin", f"{branch_name}:{branch_name}"], cwd=repo, check=False)
    run(["git", "branch", "-f", branch_name, f"origin/{branch_name}"], cwd=repo, check=False)
    return branch_name


def create_review_worktree(repo: Path, branch_name: str, invoking_cwd: Path, *, dry_run: bool) -> Path:
    review_relative = Path("_review") / "current"
    review_path = repo / review_relative

    if dry_run:
        print(f"WORKTREE_PATH={review_path}", flush=True)
        print(f"BRANCH={branch_name}", flush=True)
        print("DRY_RUN=1", flush=True)
        return review_path

    if review_path.exists():
        print("Removing existing review worktree", flush=True)
        run(["git", "worktree", "remove", str(review_relative), "--force"], cwd=repo, check=False)
        if review_path.exists():
            shutil.rmtree(review_path)
        run(["git", "worktree", "prune"], cwd=repo)

    (repo / "_review").mkdir(exist_ok=True)
    run(["git", "worktree", "add", str(review_relative), branch_name], cwd=repo)
    sync_config_to_worktree(repo, review_relative, git_toplevel(invoking_cwd))
    return review_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Create or refresh a managed review worktree.")
    parser.add_argument("pr_or_branch")
    parser.add_argument("--repo")
    parser.add_argument("--workdir")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    invoking_cwd = Path(args.workdir).expanduser().resolve() if args.workdir else Path.cwd().resolve()
    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    _, repo = repo_from_args_or_cwd(worktrees_root(workbench_root), args.repo, invoking_cwd)

    try:
        pr_input = normalize_pr_input(args.pr_or_branch)
        branch_name = fetch_pr_or_branch(repo, pr_input, dry_run=args.dry_run)
        worktree_path = create_review_worktree(repo, branch_name, invoking_cwd, dry_run=args.dry_run)
    except subprocess.CalledProcessError as exc:
        fail(f"command failed with exit code {exc.returncode}: {' '.join(exc.cmd)}")

    if not args.dry_run:
        print(f"WORKTREE_PATH={worktree_path}", flush=True)
        print(f"BRANCH={branch_name}", flush=True)
        print_short_status(worktree_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
