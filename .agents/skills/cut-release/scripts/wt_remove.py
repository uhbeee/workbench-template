#!/usr/bin/env python3
"""Remove Workbench-managed feature, hotfix, review, or release worktrees."""

from __future__ import annotations

import argparse
import subprocess
import time
from pathlib import Path

from common import (
    MANAGED_WORKTREE_KINDS,
    PROTECTED_BRANCHES,
    base_repo_path,
    fail,
    find_workbench_root,
    git_branch,
    git_dirty_status,
    git_ref_exists,
    infer_repo_name,
    repo_from_args_or_cwd,
    run,
    worktrees_root,
)


KINDS = MANAGED_WORKTREE_KINDS


def removable_paths(repo: Path) -> list[Path]:
    paths: list[Path] = []
    for kind in KINDS:
        parent = repo / kind
        if parent.is_dir():
            paths.extend(sorted(path for path in parent.iterdir() if path.is_dir()))
    return paths


def choose_interactively(repo: Path) -> str:
    paths = removable_paths(repo)
    if not paths:
        print("No removable worktrees found.")
        raise SystemExit(0)

    print("Removable worktrees:")
    for index, path in enumerate(paths, start=1):
        print(f"  {index}. {path.name} [{path.parent.name.removeprefix('_')}]")
    choice = input("Choice: ").strip()
    if not choice:
        print("Cancelled")
        raise SystemExit(0)
    if choice.isdigit():
        selected = int(choice)
        if 1 <= selected <= len(paths):
            return paths[selected - 1].name
        fail("invalid selection")
    return choice


def resolve_target(repo: Path, name: str) -> Path:
    normalized = name.strip().strip("/\\")
    if normalized in PROTECTED_BRANCHES or normalized.endswith(".git"):
        fail(f"protected worktree cannot be removed: {name}")

    raw_path = Path(normalized)
    exact_candidates = []
    if len(raw_path.parts) > 1:
        exact_candidates.append(repo / raw_path)
    exact_candidates.extend(repo / kind / normalized for kind in KINDS)

    exact = [path for path in exact_candidates if path.is_dir()]
    if len(exact) == 1:
        return exact[0]
    if len(exact) > 1:
        fail(f"ambiguous worktree name: {name}")

    matches = [path for path in removable_paths(repo) if normalized.lower() in path.name.lower()]
    if not matches:
        fail(f"no removable worktree matched: {name}")
    if len(matches) > 1:
        print("Multiple removable worktrees matched:")
        for path in matches:
            print(f"  {path}")
        fail("refine the worktree name")
    return matches[0]


def stale_paths(repo: Path, stale_days: int) -> list[Path]:
    now = int(time.time())
    threshold = stale_days * 86400
    matches: list[Path] = []
    for path in removable_paths(repo):
        raw = subprocess.run(
            ["git", "log", "-1", "--format=%ct"],
            cwd=str(path),
            text=True,
            capture_output=True,
            check=False,
        ).stdout.strip()
        try:
            last_commit = int(raw)
        except ValueError:
            last_commit = 0
        if now - last_commit >= threshold:
            matches.append(path)
    return matches


def repos_for_bulk(root: Path, repo_name: str | None, cwd: Path) -> list[tuple[str, Path]]:
    if repo_name:
        repo = base_repo_path(root, repo_name)
        if not repo.is_dir():
            fail(f"base repo does not exist: {repo}")
        return [(repo_name.removesuffix(".git"), repo)]

    inferred = infer_repo_name(root, cwd)
    if inferred:
        return [(inferred, base_repo_path(root, inferred))]

    return [(path.name.removesuffix(".git"), path) for path in sorted(root.glob("*.git")) if path.is_dir()]


def resolve_merged_base(repo: Path, base_name: str) -> str:
    if base_name.startswith("refs/") or base_name.startswith("origin/"):
        ref = base_name
    elif git_ref_exists(repo, f"refs/remotes/origin/{base_name}"):
        ref = f"origin/{base_name}"
    elif git_ref_exists(repo, f"refs/heads/{base_name}"):
        ref = base_name
    else:
        fail(f"merged target not found: {base_name}")

    if run(["git", "rev-parse", "--verify", ref], cwd=repo, check=False).returncode != 0:
        fail(f"merged target not found: {ref}")
    return ref


def merged_paths(repo: Path, base_ref: str) -> tuple[list[Path], list[tuple[Path, str, str]]]:
    run(["git", "fetch", "origin"], cwd=repo, check=False)
    matches: list[Path] = []
    skipped: list[tuple[Path, str, str]] = []

    for path in removable_paths(repo):
        branch = git_branch(path)
        dirty = git_dirty_status(path)
        if not branch:
            skipped.append((path, branch, "no-current-branch"))
            continue
        if branch in PROTECTED_BRANCHES:
            skipped.append((path, branch, "protected-branch"))
            continue
        if dirty:
            skipped.append((path, branch, "dirty"))
            continue
        if run(["git", "merge-base", "--is-ancestor", branch, base_ref], cwd=repo, check=False).returncode == 0:
            matches.append(path)

    return matches, skipped


def remove_one(
    repo: Path,
    target: Path,
    *,
    force: bool,
    yes: bool,
    delete_branch: bool,
    keep_branch: bool,
    dry_run: bool,
    require_clean: bool,
) -> None:
    target_branch = git_branch(target)
    dirty = git_dirty_status(target)
    relative = target.relative_to(repo).as_posix()

    print(f"WORKTREE_PATH={target}", flush=True)
    print(f"BRANCH={target_branch}", flush=True)
    print(f"DIRTY={'yes' if dirty else 'no'}", flush=True)
    if dirty:
        print(dirty, flush=True)

    if target_branch in PROTECTED_BRANCHES:
        fail(f"protected branch cannot be removed by this command: {target_branch}")

    command = ["git", "worktree", "remove", relative]
    if force or (dirty and yes and not require_clean):
        command.append("--force")
    print("COMMAND=" + " ".join(command), flush=True)

    if dry_run:
        print("DRY_RUN=1", flush=True)
        return

    if dirty and require_clean and not force:
        fail("worktree is dirty; re-run with --force only after explicit approval")

    if dirty and not force and not yes:
        answer = input("Worktree is dirty. Force remove? [y/N] ").strip().lower()
        if answer not in {"y", "yes"}:
            print("Cancelled", flush=True)
            raise SystemExit(1)
        command.append("--force")

    run(command, cwd=repo)
    run(["git", "worktree", "prune"], cwd=repo)
    print(f"REMOVED={target}", flush=True)

    if not target_branch or target_branch in PROTECTED_BRANCHES:
        return
    if delete_branch:
        run(["git", "branch", "-D", target_branch], cwd=repo, check=False)
        print(f"BRANCH_ACTION=deleted:{target_branch}", flush=True)
    elif keep_branch or yes:
        print(f"BRANCH_ACTION=kept:{target_branch}", flush=True)
    else:
        answer = input(f"Delete local branch '{target_branch}'? [y/N] ").strip().lower()
        if answer in {"y", "yes"}:
            run(["git", "branch", "-D", target_branch], cwd=repo, check=False)
            print(f"BRANCH_ACTION=deleted:{target_branch}", flush=True)
        else:
            print(f"BRANCH_ACTION=kept:{target_branch}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Remove a managed Workbench worktree.")
    parser.add_argument("worktree_name", nargs="?")
    parser.add_argument("--repo")
    parser.add_argument("--workdir")
    parser.add_argument("--force", "-f", action="store_true")
    parser.add_argument("--delete-branch", "-d", action="store_true")
    parser.add_argument("--keep-branch", "-k", action="store_true")
    parser.add_argument("--yes", "-y", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--require-clean", action="store_true")
    parser.add_argument("--stale", nargs="?", const="14")
    parser.add_argument("--merged-to", metavar="BRANCH", help="Bulk-remove clean managed worktrees whose branch is merged to BRANCH.")
    args = parser.parse_args()

    if args.delete_branch and args.keep_branch:
        fail("choose only one of --delete-branch or --keep-branch")

    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    root = worktrees_root(workbench_root)
    cwd = Path(args.workdir).expanduser().resolve() if args.workdir else Path.cwd().resolve()

    try:
        if args.merged_to:
            all_targets: list[tuple[Path, Path]] = []
            for repo_name, repo in repos_for_bulk(root, args.repo, cwd):
                base_ref = resolve_merged_base(repo, args.merged_to)
                targets, skipped = merged_paths(repo, base_ref)
                print(f"REPO={repo_name}", flush=True)
                print(f"MERGED_TO={base_ref}", flush=True)
                for target in targets:
                    print(f"MERGED_CANDIDATE={target.relative_to(repo).as_posix()}", flush=True)
                    all_targets.append((repo, target))
                for target, branch, reason in skipped:
                    print(f"SKIPPED={target.relative_to(repo).as_posix()} BRANCH={branch or 'none'} REASON={reason}", flush=True)
                print("", flush=True)

            if not all_targets:
                print("No clean merged managed worktrees found.", flush=True)
                if args.dry_run:
                    print("DRY_RUN=1", flush=True)
                return 0

            if args.dry_run:
                print("DRY_RUN=1", flush=True)
                return 0

            if not args.yes:
                answer = input(f"Remove {len(all_targets)} clean merged worktree(s)? [y/N] ").strip().lower()
                if answer not in {"y", "yes"}:
                    print("Cancelled", flush=True)
                    return 0

            for repo, target in all_targets:
                remove_one(
                    repo,
                    target,
                    force=False,
                    yes=True,
                    delete_branch=args.delete_branch,
                    keep_branch=True if not args.delete_branch else args.keep_branch,
                    dry_run=False,
                    require_clean=True,
                )
            return 0

        repo_name, repo = repo_from_args_or_cwd(root, args.repo, cwd)

        if args.stale is not None:
            try:
                stale_days = int(args.stale)
            except ValueError:
                fail("--stale expects a day count")
            targets = stale_paths(base_repo_path(root, repo_name), stale_days)
            if not targets:
                print(f"No stale worktrees found (threshold: {stale_days} days)")
                return 0
            print(f"Stale worktrees ({stale_days}+ days):")
            for target in targets:
                print(f"  {target.relative_to(repo).as_posix()}")
            if args.dry_run:
                print("DRY_RUN=1")
                return 0
            if not args.yes:
                answer = input("Remove all? [y/N] ").strip().lower()
                if answer not in {"y", "yes"}:
                    print("Cancelled")
                    return 0
            for target in targets:
                remove_one(
                    repo,
                    target,
                    force=True,
                    yes=True,
                    delete_branch=args.delete_branch,
                    keep_branch=args.keep_branch,
                    dry_run=False,
                    require_clean=False,
                )
            return 0

        name = args.worktree_name or choose_interactively(repo)
        target = resolve_target(repo, name)
        remove_one(
            repo,
            target,
            force=args.force,
            yes=args.yes,
            delete_branch=args.delete_branch,
            keep_branch=args.keep_branch,
            dry_run=args.dry_run,
            require_clean=args.require_clean,
        )
    except subprocess.CalledProcessError as exc:
        fail(f"command failed with exit code {exc.returncode}: {' '.join(exc.cmd)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
