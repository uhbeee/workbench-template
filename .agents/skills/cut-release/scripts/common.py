#!/usr/bin/env python3
"""Shared helpers for Workbench worktree commands."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


PROTECTED_BRANCHES = {"main", "develop", "master"}


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def run(
    command: list[str],
    *,
    cwd: Path | None = None,
    capture: bool = False,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=capture,
        check=check,
    )


def output(command: list[str], *, cwd: Path | None = None, check: bool = True) -> str:
    completed = run(command, cwd=cwd, capture=True, check=check)
    return completed.stdout.strip()


def find_workbench_root(start: Path) -> Path:
    for candidate in [start.resolve(), *start.resolve().parents]:
        if (candidate / "config.yaml").exists() and (candidate / "scripts").exists():
            return candidate
    fail(f"could not find Workbench root from {start}")


def read_config_worktrees_root(config_path: Path) -> Path | None:
    if not config_path.exists():
        return None

    in_worktrees = False
    for raw_line in config_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        if re.match(r"^worktrees\s*:", line):
            in_worktrees = True
            continue
        if in_worktrees and re.match(r"^\S", line):
            in_worktrees = False
        if in_worktrees:
            match = re.match(r"^\s+root\s*:\s*['\"]?([^'\"]+)['\"]?\s*$", line)
            if match:
                return Path(match.group(1)).expanduser()
    return None


def default_worktrees_root() -> Path:
    if os.name == "nt":
        return Path("C:/worktrees")
    return Path.home() / "Developer" / "worktrees"


def worktrees_root(workbench_root: Path) -> Path:
    env_root = os.environ.get("WORKTREE_ROOT")
    root = Path(env_root).expanduser() if env_root else read_config_worktrees_root(workbench_root / "config.yaml")
    return root or default_worktrees_root()


def normalize_repo_name(repo_name: str) -> str:
    return repo_name.removesuffix(".git")


def git_common_dir(cwd: Path) -> Path:
    raw = output(["git", "rev-parse", "--git-common-dir"], cwd=cwd)
    common = Path(raw)
    if not common.is_absolute():
        common = cwd / common
    return common.resolve()


def git_toplevel(cwd: Path) -> Path | None:
    try:
        raw = output(["git", "rev-parse", "--show-toplevel"], cwd=cwd)
    except subprocess.CalledProcessError:
        return None
    return Path(raw).resolve()


def infer_repo_name(root: Path, cwd: Path) -> str | None:
    current = cwd.resolve()
    if current.name.endswith(".git") and current.parent == root:
        return normalize_repo_name(current.name)

    try:
        common = git_common_dir(current)
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None

    try:
        relative = common.relative_to(root)
    except ValueError:
        return None

    first_part = relative.parts[0] if relative.parts else ""
    if first_part.endswith(".git"):
        return normalize_repo_name(first_part)
    return None


def base_repo_path(root: Path, repo_name: str) -> Path:
    return root / f"{normalize_repo_name(repo_name)}.git"


def branch_leaf(branch_name: str) -> str:
    return branch_name.replace("\\", "/").rstrip("/").split("/")[-1]


def git_ref_exists(repo: Path, ref: str) -> bool:
    return run(["git", "show-ref", "--verify", "--quiet", ref], cwd=repo, check=False).returncode == 0


def detect_default_branch(repo: Path) -> str | None:
    default = output(
        ["git", "symbolic-ref", "refs/remotes/origin/HEAD"],
        cwd=repo,
        check=False,
    )
    if default:
        return default.removeprefix("refs/remotes/origin/")

    for candidate in ("main", "master"):
        if git_ref_exists(repo, f"refs/remotes/origin/{candidate}"):
            return candidate
    return None


def resolve_base_ref(repo: Path, branch_name: str) -> str:
    if git_ref_exists(repo, f"refs/remotes/origin/{branch_name}"):
        return f"origin/{branch_name}"
    if git_ref_exists(repo, f"refs/heads/{branch_name}"):
        return branch_name
    fail(f"base branch not found: {branch_name}")


def git_branch(path: Path) -> str:
    try:
        return output(["git", "-C", str(path), "branch", "--show-current"])
    except subprocess.CalledProcessError:
        return ""


def git_dirty_status(path: Path) -> str:
    try:
        return output(["git", "-C", str(path), "status", "--short"])
    except subprocess.CalledProcessError:
        return ""


def print_short_status(path: Path) -> None:
    run(["git", "-C", str(path), "status", "--short", "--branch"])


def current_branch(path: Path) -> str:
    return output(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=path)


MANAGED_WORKTREE_KINDS = ("_feature", "_hotfix", "_review", "_release")


def managed_worktree_paths(repo: Path, *, include_roots: bool = False) -> list[Path]:
    paths: list[Path] = []
    if include_roots:
        for name in ("main", "develop", "master"):
            candidate = repo / name
            if candidate.is_dir():
                paths.append(candidate)
    for kind in MANAGED_WORKTREE_KINDS:
        parent = repo / kind
        if parent.is_dir():
            paths.extend(sorted(path for path in parent.iterdir() if path.is_dir()))
    return paths


def resolve_managed_worktree(repo: Path, name: str, *, include_roots: bool = False) -> Path | None:
    normalized = name.strip().strip("/\\")
    raw_path = Path(normalized)
    candidates: list[Path] = []
    if len(raw_path.parts) > 1:
        candidates.append(repo / raw_path)
    if include_roots:
        candidates.append(repo / normalized)
    candidates.extend(repo / kind / normalized for kind in MANAGED_WORKTREE_KINDS)

    exact = [path for path in candidates if path.is_dir()]
    if len(exact) == 1:
        return exact[0]

    matches = [path for path in managed_worktree_paths(repo, include_roots=include_roots) if normalized.lower() in path.name.lower()]
    if len(matches) == 1:
        return matches[0]
    return None


def copy_config_dir(source: Path, dest: Path) -> None:
    if not source.is_dir():
        return

    target = dest / source.name
    if _path_exists_or_symlink(target) and (target.is_symlink() or not target.is_dir()):
        _remove_path(target)

    if target.is_dir():
        for item in source.iterdir():
            target_item = target / item.name
            if not _path_exists_or_symlink(target_item):
                continue
            if item.is_symlink() or target_item.is_symlink():
                _remove_path(target_item)
            elif item.is_dir() and not target_item.is_dir():
                _remove_path(target_item)
            elif not item.is_dir() and target_item.is_dir():
                _remove_path(target_item)

    shutil.copytree(source, target, dirs_exist_ok=True, symlinks=True)


def _path_exists_or_symlink(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def _remove_path(path: Path) -> None:
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    else:
        path.unlink()


def sync_config_to_worktree(repo_root: Path, dest_relative: Path, invoking_worktree: Path | None) -> None:
    dest = repo_root / dest_relative
    sources: list[Path] = []
    if invoking_worktree and invoking_worktree.is_dir():
        sources.append(invoking_worktree)
    sources.extend(repo_root / name for name in ("main", "develop", "master"))

    for source in sources:
        if not source.is_dir():
            continue
        copied = False
        for config_dir in (".claude", ".agent"):
            config_source = source / config_dir
            if config_source.is_dir():
                copy_config_dir(config_source, dest)
                copied = True
        if copied:
            print(f"synced config from {source.name}", flush=True)
            return


def repo_from_args_or_cwd(root: Path, repo_name: str | None, cwd: Path) -> tuple[str, Path]:
    repo = normalize_repo_name(repo_name) if repo_name else infer_repo_name(root, cwd)
    if not repo:
        fail("could not infer repo; pass --repo <name>")
    base_repo = base_repo_path(root, repo)
    if not base_repo.is_dir():
        fail(f"base repo does not exist: {base_repo}")
    return repo, base_repo
