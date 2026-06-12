#!/usr/bin/env python3
"""Cherry-pick a merged PR onto a release branch and open a hotfix PR."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

from common import fail, find_workbench_root, git_toplevel, repo_from_args_or_cwd, run, sync_config_to_worktree, worktrees_root


def gh_json(repo: Path, pr_number: str) -> dict:
    if not shutil.which("gh"):
        fail("GitHub CLI (gh) is required for wt_hotfix_pr.py")
    raw = subprocess.run(
        [
            "gh",
            "pr",
            "view",
            pr_number,
            "--json",
            "state,mergeCommit,title,headRefName,baseRefName,commits",
        ],
        cwd=str(repo),
        text=True,
        capture_output=True,
        check=False,
    )
    if raw.returncode != 0:
        fail(f"could not read PR #{pr_number}; gh exited {raw.returncode}")
    return json.loads(raw.stdout)


def git_text(repo: Path, command: list[str], *, check: bool = True) -> str:
    return subprocess.run(command, cwd=str(repo), text=True, capture_output=True, check=check).stdout.strip()


def remote_release_branches(repo: Path) -> list[str]:
    raw = git_text(repo, ["git", "branch", "-r", "--list", "origin/release/*", "--sort=-committerdate"])
    return [line.strip().removeprefix("origin/") for line in raw.splitlines() if line.strip()]


def pick_release_branch(repo: Path, explicit: str | None) -> str:
    if explicit:
        if run(["git", "show-ref", "--verify", "--quiet", f"refs/remotes/origin/{explicit}"], cwd=repo, check=False).returncode != 0:
            fail(f"release branch not found on remote: {explicit}")
        return explicit

    branches = remote_release_branches(repo)
    if not branches:
        fail("no origin/release/* branches found; pass --release <branch>")

    latest = branches[0]
    print("RELEASE_CANDIDATES=" + ",".join(branches[:5]), flush=True)
    return latest


def ticket_from(pr_title: str, pr_head: str, explicit: str | None) -> str:
    if explicit:
        return explicit
    match = re.search(r"\b[A-Z][A-Z0-9]+-\d+\b", f"{pr_title} {pr_head}")
    return match.group(0) if match else "none"


def detect_strategy(repo: Path, data: dict) -> tuple[str, list[str], str]:
    merge_commit = data.get("mergeCommit", {}).get("oid")
    commits = data.get("commits") or []
    commit_count = len(commits)

    parents = git_text(repo, ["git", "cat-file", "-p", merge_commit], check=False).splitlines()
    parent_count = sum(1 for line in parents if line.startswith("parent "))

    if parent_count > 1:
        return "merge commit", ["git", "cherry-pick", "-m", "1", merge_commit], merge_commit[:8]

    if commit_count <= 1:
        return "squash merge (single commit)", ["git", "cherry-pick", merge_commit], merge_commit[:8]

    last_pr_commit = commits[-1].get("oid") if commits else ""
    if last_pr_commit and run(["git", "cat-file", "-e", last_pr_commit], cwd=repo, check=False).returncode == 0:
        merge_patch = subprocess.run(
            "git diff-tree -p "
            + merge_commit
            + " | git patch-id --stable | awk '{print $1}'",
            cwd=str(repo),
            text=True,
            shell=True,
            capture_output=True,
            check=False,
        ).stdout.strip()
        pr_patch = subprocess.run(
            "git diff-tree -p "
            + last_pr_commit
            + " | git patch-id --stable | awk '{print $1}'",
            cwd=str(repo),
            text=True,
            shell=True,
            capture_output=True,
            check=False,
        ).stdout.strip()
        if merge_patch and merge_patch == pr_patch:
            return (
                f"rebase merge ({commit_count} commits)",
                ["git", "cherry-pick", f"{merge_commit}~{commit_count}..{merge_commit}"],
                f"{merge_commit[:8]} range",
            )

    return "squash merge (single commit)", ["git", "cherry-pick", merge_commit], merge_commit[:8]


def pr_body(pr_number: str, ticket: str, strategy: str, merge_commit: str) -> str:
    return "\n".join(
        [
            "## Cherry-pick Info",
            f"- **Original PR:** #{pr_number}",
            f"- **Jira:** {ticket}",
            f"- **Merge strategy:** {strategy}",
            f"- **Merge commit:** {merge_commit[:8]}",
            "",
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Cherry-pick a merged PR onto a release branch.")
    parser.add_argument("pr_number")
    parser.add_argument("--ticket")
    parser.add_argument("--release", dest="release_branch")
    parser.add_argument("--repo")
    parser.add_argument("--workdir")
    parser.add_argument("--quick", "-q", action="store_true", help="Accepted for compatibility; this script is non-interactive by default.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--yes", "-y", action="store_true")
    parser.add_argument("--force-recreate", action="store_true", help="Remove an existing hotfix worktree with the same name.")
    args = parser.parse_args()

    cwd = Path(args.workdir).expanduser().resolve() if args.workdir else Path.cwd().resolve()
    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    _, repo = repo_from_args_or_cwd(worktrees_root(workbench_root), args.repo, cwd)

    try:
        run(["git", "fetch", "origin"], cwd=repo)
        data = gh_json(repo, args.pr_number)
        state = data.get("state")
        title = data.get("title") or ""
        head = data.get("headRefName") or ""
        base = data.get("baseRefName") or ""
        merge_commit = data.get("mergeCommit", {}).get("oid")

        if state == "CLOSED":
            fail(f"PR #{args.pr_number} was closed without merging: {title}")
        if state != "MERGED":
            fail(f"PR #{args.pr_number} is not merged (state: {state})")
        if not merge_commit:
            fail(f"could not determine merge commit for PR #{args.pr_number}")

        strategy, cherry_pick_cmd, commit_display = detect_strategy(repo, data)
        release_branch = pick_release_branch(repo, args.release_branch)
        ticket = ticket_from(title, head, args.ticket)

        release_name = release_branch.removeprefix("release/")
        release_safe = release_name.replace("/", "-")
        ticket_slug = "" if ticket == "none" else f"{ticket}-"
        hotfix_branch = f"hotfix/{ticket_slug}pr-{args.pr_number}-to-{release_name}"
        worktree_relative = Path("_hotfix") / f"hotfix-pr-{args.pr_number}-to-{release_safe}"
        worktree_path = repo / worktree_relative

        if run(["git", "merge-base", "--is-ancestor", merge_commit, f"origin/{release_branch}"], cwd=repo, check=False).returncode == 0:
            print(f"ALREADY_ON_RELEASE={release_branch}", flush=True)
            return 0

        print(f"PR=#{args.pr_number}", flush=True)
        print(f"TITLE={title}", flush=True)
        print(f"HEAD={head}", flush=True)
        print(f"BASE={base}", flush=True)
        print(f"TICKET={ticket}", flush=True)
        print(f"MERGE_COMMIT={merge_commit}", flush=True)
        print(f"STRATEGY={strategy}", flush=True)
        print(f"COMMIT={commit_display}", flush=True)
        print(f"RELEASE_BRANCH={release_branch}", flush=True)
        print(f"HOTFIX_BRANCH={hotfix_branch}", flush=True)
        print(f"WORKTREE_PATH={worktree_path}", flush=True)

        if args.dry_run:
            print("DRY_RUN=1", flush=True)
            return 0

        if not args.yes:
            answer = input("Proceed? [Y/n] ").strip().lower()
            if answer not in {"", "y", "yes"}:
                print("Cancelled", flush=True)
                return 1

        if worktree_path.exists():
            if not args.force_recreate:
                fail(f"worktree already exists: {worktree_path}; pass --force-recreate after confirming it is safe")
            run(["git", "worktree", "remove", str(worktree_relative), "--force"], cwd=repo, check=False)
            if worktree_path.exists():
                shutil.rmtree(worktree_path)
            run(["git", "worktree", "prune"], cwd=repo)

        (repo / "_hotfix").mkdir(exist_ok=True)
        run(["git", "worktree", "add", "-b", hotfix_branch, str(worktree_relative), f"origin/{release_branch}"], cwd=repo)
        sync_config_to_worktree(repo, worktree_relative, git_toplevel(cwd))

        cherry_pick_result = subprocess.run(cherry_pick_cmd, cwd=str(worktree_path), text=True, check=False)
        if cherry_pick_result.returncode != 0:
            conflicts = git_text(worktree_path, ["git", "diff", "--name-only", "--diff-filter=U"], check=False)
            print("CONFLICT=1", flush=True)
            print(f"WORKTREE_PATH={worktree_path}", flush=True)
            if conflicts:
                print(conflicts, flush=True)
            return 1

        run(["git", "push", "-u", "origin", hotfix_branch], cwd=worktree_path)
        title_prefix = "" if ticket == "none" else f"[{ticket}] "
        pr_title = f"{title_prefix}Cherry-pick PR #{args.pr_number} to {release_branch}"
        pr_url = git_text(
            worktree_path,
            ["gh", "pr", "create", "--base", release_branch, "--title", pr_title, "--body", pr_body(args.pr_number, ticket, strategy, merge_commit)],
        )
        print(f"PR_URL={pr_url}", flush=True)
        print(f"CLEANUP_COMMAND=wt-hotfix-done hotfix-pr-{args.pr_number}-to-{release_safe}", flush=True)
    except subprocess.CalledProcessError as exc:
        fail(f"command failed with exit code {exc.returncode}: {' '.join(exc.cmd)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
