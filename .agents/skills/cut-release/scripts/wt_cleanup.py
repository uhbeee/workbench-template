#!/usr/bin/env python3
"""Audit and clean up managed Workbench worktrees.

Default behavior is a READ-ONLY audit. The audit walks every managed *.git
repo under the worktrees root, lists feature/hotfix/review/release worktrees,
queries `gh` for each branch's PR state, and classifies each worktree as one
of:

  clean-merged         clean working tree, branch's PR is merged
  clean-no-pr          clean working tree, no PR exists
  clean-open-pr        clean working tree, PR is open
  clean-stale          clean working tree, no PR, >= --stale-behind commits behind base
  dirty-tooling-only   only ignored tooling files dirty (counts as removable)
  dirty-real           real uncommitted code changes (preserve unless forced)
  protected            main/develop/master (never targets)

"Ignored tooling files" are matched against patterns in
context/repo-context/dirt-allowlist.yaml (global list + per-repo overrides).
Override the allowlist file with --allowlist <path> or skip it entirely with
--include-tooling-dirt.

Common usage:

  # Audit everything (read-only, default)
  python3 wt_cleanup.py

  # Audit a single repo
  python3 wt_cleanup.py --repo recruit-ui

  # Machine-readable
  python3 wt_cleanup.py --format json

  # Remove every clean+merged worktree across all repos (keep branches)
  python3 wt_cleanup.py --execute clean-merged --yes

  # Remove clean+merged AND dirty-tooling-only (force-removing tooling residue)
  python3 wt_cleanup.py --execute clean-merged,dirty-tooling-only --yes

  # Prune stale git worktree metadata (the old wt_cleanup behavior)
  python3 wt_cleanup.py --prune-stale

The script NEVER force-removes dirty-real worktrees. Use wt_remove.py
directly with explicit per-worktree --force after reviewing the diff.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Iterable

from common import (
    MANAGED_WORKTREE_KINDS,
    PROTECTED_BRANCHES,
    base_repo_path,
    fail,
    find_workbench_root,
    git_branch,
    git_dirty_status,
    run,
    worktrees_root,
)


REMOVABLE_CLASSIFICATIONS = {"clean-merged", "clean-stale", "dirty-tooling-only"}


@dataclass
class WorktreeReport:
    repo: str
    path: str
    kind: str
    branch: str
    pr_number: int | None = None
    pr_state: str | None = None
    pr_merged_at: str | None = None
    pr_title: str | None = None
    ahead: int = 0
    behind: int = 0
    base_ref: str = ""
    dirty_real: list[str] = field(default_factory=list)
    dirty_ignored: list[str] = field(default_factory=list)
    classification: str = ""
    recommendation: str = ""
    notes: list[str] = field(default_factory=list)


def load_allowlist(path: Path | None) -> tuple[list[str], dict[str, list[str]]]:
    if path is None or not path.is_file():
        return [], {}
    try:
        import yaml  # type: ignore
        data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except ImportError:
        data = _parse_simple_yaml(path)
    global_patterns = [str(p) for p in (data.get("global") or [])]
    per_repo_raw = data.get("per_repo") or {}
    per_repo = {repo: [str(p) for p in (patterns or [])] for repo, patterns in per_repo_raw.items()}
    return global_patterns, per_repo


def _parse_simple_yaml(path: Path) -> dict:
    """Minimal fallback YAML parser for the dirt-allowlist format.

    Only handles the exact shape this allowlist uses: top-level `global:` and
    `per_repo:` keys, list-of-strings under each (with optional quoting).
    """
    result: dict = {"global": [], "per_repo": {}}
    section: str | None = None
    current_repo: str | None = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith("global:"):
            section = "global"
            current_repo = None
            continue
        if line.startswith("per_repo:"):
            section = "per_repo"
            current_repo = None
            continue
        if line.startswith(("schema_version:", "description:")) or section is None:
            continue
        if section == "global" and line.startswith("  - "):
            result["global"].append(_strip_yaml_scalar(line[4:]))
        elif section == "per_repo":
            if line.startswith("  ") and not line.startswith("    "):
                repo_name = line.strip().rstrip(":")
                current_repo = repo_name
                result["per_repo"][current_repo] = []
            elif current_repo and line.startswith("    - "):
                result["per_repo"][current_repo].append(_strip_yaml_scalar(line[6:]))
    return result


def _strip_yaml_scalar(value: str) -> str:
    value = value.strip()
    if value.startswith(("'", '"')) and value.endswith(("'", '"')) and len(value) >= 2:
        return value[1:-1]
    return value


def classify_dirty_line(line: str, patterns: Iterable[str]) -> bool:
    """Return True if a `git status --short` line matches an ignored pattern."""
    if len(line) < 3:
        return False
    path = line[3:].strip()
    if " -> " in path:
        path = path.split(" -> ")[-1].strip()
    path = path.strip('"').replace("\\", "/")
    for pattern in patterns:
        norm = pattern.replace("\\", "/").strip()
        if not norm:
            continue
        if norm in path:
            return True
    return False


def list_worktrees(repo: Path) -> list[tuple[str, Path]]:
    out: list[tuple[str, Path]] = []
    for kind in MANAGED_WORKTREE_KINDS:
        parent = repo / kind
        if parent.is_dir():
            for path in sorted(parent.iterdir()):
                if path.is_dir():
                    out.append((kind, path))
    return out


def ahead_behind(repo: Path, branch: str, base_ref: str) -> tuple[int, int]:
    if not branch or not base_ref:
        return 0, 0
    raw = run(
        ["git", "rev-list", "--left-right", "--count", f"{base_ref}...{branch}"],
        cwd=repo,
        capture=True,
        check=False,
    ).stdout.strip()
    if not raw:
        return 0, 0
    parts = raw.split()
    if len(parts) != 2:
        return 0, 0
    try:
        behind, ahead = int(parts[0]), int(parts[1])
    except ValueError:
        return 0, 0
    return ahead, behind


def resolve_base_ref(repo: Path, prefer: str | None = None) -> str:
    candidates = []
    if prefer:
        candidates.append(prefer)
    candidates.extend(["origin/develop", "origin/main", "origin/master"])
    for ref in candidates:
        if run(["git", "rev-parse", "--verify", ref], cwd=repo, capture=True, check=False).returncode == 0:
            return ref
    return ""


def gh_pr_status(repo: Path, branch: str) -> dict | None:
    if not shutil.which("gh"):
        return None
    result = run(
        [
            "gh",
            "pr",
            "list",
            "--head",
            branch,
            "--state",
            "all",
            "--json",
            "number,state,title,mergedAt",
            "--limit",
            "1",
        ],
        cwd=repo,
        capture=True,
        check=False,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return None
    try:
        items = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    return items[0] if items else None


def discover_repos(root: Path, repo_filter: str | None, aliases: dict[str, str]) -> list[tuple[str, Path]]:
    if repo_filter:
        canonical = aliases.get(repo_filter, repo_filter)
        path = base_repo_path(root, canonical)
        if not path.is_dir():
            fail(f"repo not found under {root}: {repo_filter}")
        return [(canonical, path)]
    return sorted(
        ((p.name.removesuffix(".git"), p) for p in root.glob("*.git") if p.is_dir()),
        key=lambda t: t[0].lower(),
    )


def load_aliases(workbench_root: Path) -> dict[str, str]:
    repos_yaml = workbench_root / "context" / "repo-context" / "repos.yaml"
    if not repos_yaml.is_file():
        return {}
    aliases: dict[str, str] = {}
    current_repo: str | None = None
    for raw in repos_yaml.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if line.startswith("  ") and not line.startswith("    ") and line.endswith(":"):
            current_repo = line.strip().rstrip(":")
            aliases[current_repo] = current_repo
        elif current_repo and line.lstrip().startswith("aliases:"):
            bracket = line.split("[", 1)
            if len(bracket) == 2:
                inner = bracket[1].rsplit("]", 1)[0]
                for alias in [a.strip() for a in inner.split(",") if a.strip()]:
                    aliases[alias] = current_repo
    return aliases


def audit_worktree(
    repo_name: str,
    repo: Path,
    kind: str,
    path: Path,
    *,
    base_ref: str,
    global_patterns: list[str],
    per_repo_patterns: list[str],
    check_pr: bool,
    stale_behind_threshold: int,
    include_tooling_dirt: bool,
) -> WorktreeReport:
    branch = git_branch(path)
    report = WorktreeReport(
        repo=repo_name,
        path=str(path),
        kind=kind.lstrip("_"),
        branch=branch,
    )

    if branch in PROTECTED_BRANCHES:
        report.classification = "protected"
        report.recommendation = "skip"
        return report

    status_raw = git_dirty_status(path)
    if status_raw:
        all_patterns = list(global_patterns) + list(per_repo_patterns)
        for line in status_raw.splitlines():
            if include_tooling_dirt or not classify_dirty_line(line, all_patterns):
                report.dirty_real.append(line)
            else:
                report.dirty_ignored.append(line)

    if branch:
        ahead, behind = ahead_behind(repo, branch, base_ref) if base_ref else (0, 0)
        report.ahead = ahead
        report.behind = behind
        report.base_ref = base_ref

    if check_pr and branch:
        pr = gh_pr_status(repo, branch)
        if pr:
            report.pr_number = pr.get("number")
            report.pr_state = pr.get("state")
            report.pr_merged_at = pr.get("mergedAt")
            report.pr_title = pr.get("title")

    report.classification, report.recommendation = derive_classification(
        report,
        stale_behind_threshold=stale_behind_threshold,
    )
    return report


def derive_classification(report: WorktreeReport, *, stale_behind_threshold: int) -> tuple[str, str]:
    has_real_dirt = bool(report.dirty_real)
    has_only_tooling = bool(report.dirty_ignored) and not has_real_dirt
    pr_merged = report.pr_state == "MERGED"
    pr_open = report.pr_state == "OPEN"
    pr_none = report.pr_state is None

    if has_real_dirt:
        if pr_merged:
            return "dirty-real-merged", "review_before_removing"
        if pr_open:
            return "dirty-real-open-pr", "keep"
        return "dirty-real", "keep_or_review"

    if has_only_tooling:
        if pr_merged or pr_none:
            return "dirty-tooling-only", "force_remove_safe"
        if pr_open:
            return "dirty-tooling-open-pr", "keep"
        return "dirty-tooling-only", "force_remove_safe"

    if pr_merged:
        return "clean-merged", "remove"
    if pr_open:
        return "clean-open-pr", "keep"
    if report.ahead == 0 and report.behind >= stale_behind_threshold:
        return "clean-stale", "remove_or_review"
    if report.ahead == 0 and report.behind == 0:
        return "clean-no-progress", "remove_or_review"
    return "clean-no-pr", "review"


def remove_worktree(
    workbench_root: Path,
    repo_name: str,
    leaf_name: str,
    *,
    force: bool,
    delete_branch: bool,
) -> bool:
    cmd = [
        sys.executable,
        str(workbench_root / "scripts" / "worktrees" / "wt_remove.py"),
        "--repo",
        repo_name,
        leaf_name,
        "--yes",
    ]
    if force:
        cmd.append("--force")
    if delete_branch:
        cmd.append("--delete-branch")
    else:
        cmd.append("--keep-branch")
    result = subprocess.run(cmd, check=False)
    return result.returncode == 0


def prune_stale_metadata(root: Path, dry_run: bool) -> None:
    """Backwards-compatible behavior from the original wt_cleanup.py."""
    for repo in sorted(path for path in root.glob("*.git") if path.is_dir()):
        raw = subprocess.run(
            ["git", "worktree", "list", "--porcelain"],
            cwd=str(repo),
            text=True,
            capture_output=True,
            check=False,
        ).stdout
        stale = sum(1 for line in raw.splitlines() if "prunable" in line)
        repo_name = repo.name.removesuffix(".git")
        if stale:
            print(f"{repo_name}: STALE={stale}", flush=True)
            if not dry_run:
                run(["git", "worktree", "prune"], cwd=repo, check=False)
                print(f"{repo_name}: PRUNED=1", flush=True)
        else:
            print(f"{repo_name}: clean", flush=True)


def format_report_text(reports: list[WorktreeReport]) -> str:
    if not reports:
        return "No managed worktrees found."
    lines: list[str] = []
    by_repo: dict[str, list[WorktreeReport]] = {}
    for r in reports:
        by_repo.setdefault(r.repo, []).append(r)
    for repo in sorted(by_repo):
        items = by_repo[repo]
        lines.append(f"REPO={repo}")
        for r in items:
            lines.append(f"  {r.kind}/{Path(r.path).name}")
            lines.append(f"    BRANCH={r.branch or '(none)'}")
            if r.pr_number is not None:
                merged_bit = f" merged_at={r.pr_merged_at}" if r.pr_merged_at else ""
                lines.append(f"    PR=#{r.pr_number} state={r.pr_state}{merged_bit}")
                if r.pr_title:
                    lines.append(f"    PR_TITLE={r.pr_title}")
            else:
                lines.append("    PR=none")
            if r.base_ref:
                lines.append(f"    AHEAD/BEHIND ({r.base_ref})={r.ahead}/{r.behind}")
            lines.append(f"    DIRTY_REAL={len(r.dirty_real)}")
            for line in r.dirty_real[:6]:
                lines.append(f"      {line}")
            if len(r.dirty_real) > 6:
                lines.append(f"      ...({len(r.dirty_real) - 6} more)")
            lines.append(f"    DIRTY_IGNORED={len(r.dirty_ignored)}")
            lines.append(f"    CLASSIFICATION={r.classification}")
            lines.append(f"    RECOMMENDATION={r.recommendation}")
        lines.append("")
    counts: dict[str, int] = {}
    for r in reports:
        counts[r.classification] = counts.get(r.classification, 0) + 1
    lines.append("SUMMARY:")
    for cls in sorted(counts):
        lines.append(f"  {cls}={counts[cls]}")
    return "\n".join(lines)


def format_report_json(reports: list[WorktreeReport]) -> str:
    return json.dumps([asdict(r) for r in reports], indent=2)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Audit and clean up managed Workbench worktrees.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--repo", help="Limit to a single repo (canonical name or alias).")
    parser.add_argument(
        "--execute",
        metavar="CLASSES",
        help=(
            "Comma-separated classifications to remove (e.g. 'clean-merged' or "
            "'clean-merged,dirty-tooling-only,clean-stale'). Omit for read-only audit."
        ),
    )
    parser.add_argument("--yes", "-y", action="store_true", help="Skip the confirm prompt when --execute is set.")
    parser.add_argument("--dry-run", action="store_true", help="With --execute, print actions without running them.")
    parser.add_argument("--keep-branch", action="store_true", help="Default: keep local branches after removal.")
    parser.add_argument("--delete-branch", action="store_true", help="Delete local branches after removal.")
    parser.add_argument("--format", choices=["text", "json"], default="text")
    parser.add_argument("--no-pr-check", action="store_true", help="Skip `gh pr list` queries (faster, but no PR state).")
    parser.add_argument(
        "--include-tooling-dirt",
        action="store_true",
        help="Treat AI tooling files (.claude/, .codex/, screenshots, etc.) as real dirt.",
    )
    parser.add_argument(
        "--stale-behind",
        type=int,
        default=40,
        help="Minimum commits behind base to flag as clean-stale (default: 40).",
    )
    parser.add_argument("--allowlist", help="Path to dirt-allowlist.yaml override.")
    parser.add_argument(
        "--prune-stale",
        action="store_true",
        help="Run only `git worktree prune` across all repos (old wt_cleanup behavior).",
    )
    args = parser.parse_args()

    if args.keep_branch and args.delete_branch:
        fail("choose only one of --keep-branch or --delete-branch")

    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    root = worktrees_root(workbench_root)

    if args.prune_stale:
        prune_stale_metadata(root, dry_run=args.dry_run)
        return 0

    allowlist_path = (
        Path(args.allowlist).expanduser().resolve()
        if args.allowlist
        else workbench_root / "context" / "repo-context" / "dirt-allowlist.yaml"
    )
    global_patterns, per_repo_patterns = load_allowlist(allowlist_path)

    aliases = load_aliases(workbench_root)
    repos = discover_repos(root, args.repo, aliases)

    reports: list[WorktreeReport] = []
    for repo_name, repo in repos:
        base_ref = resolve_base_ref(repo)
        repo_patterns = per_repo_patterns.get(repo_name, [])
        for kind, path in list_worktrees(repo):
            reports.append(
                audit_worktree(
                    repo_name,
                    repo,
                    kind,
                    path,
                    base_ref=base_ref,
                    global_patterns=global_patterns,
                    per_repo_patterns=repo_patterns,
                    check_pr=not args.no_pr_check,
                    stale_behind_threshold=args.stale_behind,
                    include_tooling_dirt=args.include_tooling_dirt,
                )
            )

    if args.format == "json":
        print(format_report_json(reports))
    else:
        print(format_report_text(reports))

    if not args.execute:
        return 0

    selected = {c.strip() for c in args.execute.split(",") if c.strip()}
    unknown = selected - REMOVABLE_CLASSIFICATIONS
    if unknown:
        fail(
            f"unknown classes for --execute: {sorted(unknown)}. "
            f"Allowed: {sorted(REMOVABLE_CLASSIFICATIONS)}"
        )

    targets = [r for r in reports if r.classification in selected]
    if not targets:
        print("\nNo worktrees match the selected classifications.")
        return 0

    print(f"\nWill remove {len(targets)} worktree(s):")
    for r in targets:
        print(f"  {r.repo}/{Path(r.path).name} [{r.classification}]")

    if args.dry_run:
        print("\nDRY_RUN=1 — no changes made.")
        return 0

    if not args.yes:
        try:
            answer = input("\nProceed? [y/N] ").strip().lower()
        except EOFError:
            answer = ""
        if answer not in {"y", "yes"}:
            print("Cancelled.")
            return 0

    delete_branch = args.delete_branch
    failures = 0
    for r in targets:
        leaf = Path(r.path).name
        force = r.classification in {"dirty-tooling-only"}
        ok = remove_worktree(
            workbench_root,
            r.repo,
            leaf,
            force=force,
            delete_branch=delete_branch,
        )
        if not ok:
            failures += 1
            print(f"FAILED: {r.repo}/{leaf}")

    if failures:
        print(f"\n{failures} removal(s) failed.")
        return 1
    print(f"\nRemoved {len(targets)} worktree(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
