#!/usr/bin/env python3
"""Create and push a release branch plus a managed release worktree."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

from common import (
    fail,
    find_workbench_root,
    git_ref_exists,
    git_toplevel,
    print_short_status,
    repo_from_args_or_cwd,
    run,
    sync_config_to_worktree,
    worktrees_root,
)


FLAT = "_FLAT_"


def remote_release_branches(repo: Path) -> list[str]:
    raw = subprocess.run(
        ["git", "branch", "-r", "--list", "origin/release/*", "--sort=-committerdate"],
        cwd=str(repo),
        text=True,
        capture_output=True,
        check=True,
    ).stdout
    return [line.strip().removeprefix("origin/") for line in raw.splitlines() if line.strip()]


def release_prefixes(branches: list[str]) -> tuple[list[str], dict[str, str], dict[str, int]]:
    order: list[str] = []
    latest: dict[str, str] = {}
    counts: dict[str, int] = {}

    for branch in branches:
        remainder = branch.removeprefix("release/")
        if "/" in remainder:
            prefix, date_part = remainder.split("/", 1)
        else:
            prefix, date_part = FLAT, remainder
        if not date_part or not date_part[0].isdigit():
            continue
        if prefix not in counts:
            counts[prefix] = 0
            order.append(prefix)
            latest[prefix] = date_part
        counts[prefix] += 1
    return order, latest, counts


def detect_date_format(value: str) -> str:
    if re.fullmatch(r"[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?", value):
        return "YYYY.MM.DD"
    if re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value):
        return "YYYY-MM-DD"
    if re.fullmatch(r"[0-9]{2}-[0-9]{2}-[0-9]{2}", value):
        return "MM-DD-YY"
    if re.fullmatch(r"[0-9]{2}-[0-9]{2}-[0-9]{4}", value):
        return "MM-DD-YYYY"
    return "unknown"


def format_today(fmt: str) -> str:
    today = date.today()
    if fmt == "YYYY.MM.DD":
        return today.strftime("%Y.%m.%d")
    if fmt == "YYYY-MM-DD":
        return today.strftime("%Y-%m-%d")
    if fmt == "MM-DD-YY":
        return today.strftime("%m-%d-%y")
    if fmt == "MM-DD-YYYY":
        return today.strftime("%m-%d-%Y")
    fail(f"unsupported date format: {fmt}")


def release_worktree_relative(release_name: str) -> Path:
    leaf = release_name.removeprefix("release/").replace("/", "-")
    return Path("_release") / leaf


def select_prefix(prefix: str | None, order: list[str], latest: dict[str, str], counts: dict[str, int]) -> str:
    if not order:
        fail("no valid date-based release branches found")
    if prefix:
        if prefix in order:
            return prefix
        available = ", ".join("(flat)" if item == FLAT else item for item in order)
        fail(f"release prefix not found: {prefix}; available: {available}")
    if len(order) == 1:
        return order[0]

    print("Release prefixes:", flush=True)
    for index, item in enumerate(order, start=1):
        label = "(flat)" if item == FLAT else item
        example = f"release/{latest[item]}" if item == FLAT else f"release/{item}/{latest[item]}"
        print(f"  {index}. {label} - e.g. {example} ({counts[item]} branches)", flush=True)

    if not sys.stdin.isatty():
        fail("multiple release prefixes found; pass prefix explicitly")

    selected = input("Select prefix (number or name): ").strip()
    if not selected:
        fail("cancelled")
    if selected.isdigit() and 1 <= int(selected) <= len(order):
        return order[int(selected) - 1]
    for item in order:
        if selected == item or (selected.lower() == "flat" and item == FLAT):
            return item
    fail(f"release prefix not found: {selected}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Create and push a release branch plus a managed release worktree.")
    parser.add_argument("prefix", nargs="?")
    parser.add_argument("--repo")
    parser.add_argument("--source")
    parser.add_argument("--date")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--yes", "-y", action="store_true")
    parser.add_argument("--workdir")
    args = parser.parse_args()

    invoking_cwd = Path(args.workdir).expanduser().resolve() if args.workdir else Path.cwd().resolve()
    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    repo_name, repo = repo_from_args_or_cwd(worktrees_root(workbench_root), args.repo, invoking_cwd)

    try:
        run(["git", "fetch", "origin"], cwd=repo)
        source_branch = args.source
        if not source_branch:
            if git_ref_exists(repo, "refs/remotes/origin/develop"):
                source_branch = "develop"
            elif git_ref_exists(repo, "refs/remotes/origin/main"):
                source_branch = "main"
            else:
                fail("could not determine source branch; pass --source <branch>")
        if not git_ref_exists(repo, f"refs/remotes/origin/{source_branch}"):
            fail(f"source branch not found: origin/{source_branch}")

        branches = remote_release_branches(repo)
        if not branches:
            fail("no existing origin/release/* branches found; cannot infer naming convention")

        order, latest, counts = release_prefixes(branches)
        selected_prefix = select_prefix(args.prefix, order, latest, counts)
        date_format = detect_date_format(latest[selected_prefix])
        if date_format == "unknown":
            fail(f"could not detect date format from latest release branch: {latest[selected_prefix]}")

        date_part = args.date or format_today(date_format)
        release_name = f"release/{date_part}" if selected_prefix == FLAT else f"release/{selected_prefix}/{date_part}"
        if git_ref_exists(repo, f"refs/remotes/origin/{release_name}"):
            if date_format == "YYYY.MM.DD":
                patch = 1
                while git_ref_exists(repo, f"refs/remotes/origin/{release_name}.{patch}"):
                    patch += 1
                release_name = f"{release_name}.{patch}"
            else:
                fail(f"release branch already exists on remote: {release_name}")

        source_sha = subprocess.run(
            ["git", "rev-parse", "--short", f"origin/{source_branch}"],
            cwd=str(repo),
            text=True,
            capture_output=True,
            check=True,
        ).stdout.strip()
        worktree_relative = release_worktree_relative(release_name)
        worktree_path = repo / worktree_relative

        print(f"REPO={repo_name}", flush=True)
        print(f"BRANCH={release_name}", flush=True)
        print(f"SOURCE=origin/{source_branch}", flush=True)
        print(f"SOURCE_SHA={source_sha}", flush=True)
        print(f"FORMAT={date_format}", flush=True)
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
            fail(f"release worktree already exists: {worktree_path}")

        (repo / "_release").mkdir(exist_ok=True)
        invoking_worktree = git_toplevel(invoking_cwd)
        if git_ref_exists(repo, f"refs/heads/{release_name}"):
            run(["git", "worktree", "add", str(worktree_relative), release_name], cwd=repo)
        else:
            run(["git", "worktree", "add", "-b", release_name, str(worktree_relative), f"origin/{source_branch}"], cwd=repo)
        sync_config_to_worktree(repo, worktree_relative, invoking_worktree)

        run(["git", "push", "-u", "origin", release_name], cwd=worktree_path)
        print(f"CREATED={release_name}", flush=True)
        print(f"WORKTREE_PATH={worktree_path}", flush=True)
        print_short_status(worktree_path)
    except subprocess.CalledProcessError as exc:
        fail(f"command failed with exit code {exc.returncode}: {' '.join(exc.cmd)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
