#!/usr/bin/env python3
"""Promote Claude Code permissions found in worktrees to global settings."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

from common import fail, find_workbench_root, git_common_dir, run, worktrees_root


def read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {path}: {exc}")


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def worktree_paths(repo: Path) -> list[Path]:
    raw = subprocess.run(
        ["git", "worktree", "list", "--porcelain"],
        cwd=str(repo),
        text=True,
        capture_output=True,
        check=False,
    ).stdout
    paths: list[Path] = []
    for line in raw.splitlines():
        if line.startswith("worktree "):
            paths.append(Path(line.removeprefix("worktree ")))
    return paths


def settings_files(workbench_root: Path, cwd: Path, scan_all: bool) -> list[Path]:
    root = worktrees_root(workbench_root)
    repos: list[Path]
    if scan_all:
        repos = sorted(path for path in root.glob("*.git") if path.is_dir())
    else:
        try:
            repos = [git_common_dir(cwd)]
        except subprocess.CalledProcessError:
            fail("not in a git repository; pass --all to scan all managed repos")

    files: list[Path] = []
    for repo in repos:
        for worktree in worktree_paths(repo):
            settings = worktree / ".claude" / "settings.local.json"
            if settings.is_file():
                files.append(settings)
    return files


def collect_permissions(files: list[Path]) -> set[str]:
    permissions: set[str] = set()
    for file in files:
        data = read_json(file)
        allow = data.get("permissions", {}).get("allow", [])
        if isinstance(allow, list):
            permissions.update(str(item) for item in allow)
    return permissions


def main() -> int:
    parser = argparse.ArgumentParser(description="Promote worktree Claude permissions to global settings.")
    parser.add_argument("--all", action="store_true", help="Scan all managed repos.")
    parser.add_argument("--apply-all", action="store_true", help="Apply all missing permissions without prompting.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--workdir")
    args = parser.parse_args()

    cwd = Path(args.workdir).expanduser().resolve() if args.workdir else Path.cwd().resolve()
    workbench_root = find_workbench_root(Path(__file__).resolve().parent)
    files = settings_files(workbench_root, cwd, args.all)

    if not files:
        print("No worktree settings files found.", flush=True)
        return 0

    global_settings = Path.home() / ".claude" / "settings.local.json"
    global_data = read_json(global_settings)
    permissions = global_data.setdefault("permissions", {})
    allow = permissions.setdefault("allow", [])
    if not isinstance(allow, list):
        fail(f"{global_settings} permissions.allow must be a list")

    existing = {str(item) for item in allow}
    missing = sorted(collect_permissions(files) - existing)

    print(f"SCANNED_FILES={len(files)}", flush=True)
    print(f"GLOBAL_SETTINGS={global_settings}", flush=True)
    if not missing:
        print("MISSING_PERMISSIONS=0", flush=True)
        return 0

    print(f"MISSING_PERMISSIONS={len(missing)}", flush=True)
    for permission in missing:
        print(f"PERMISSION={permission}", flush=True)

    if args.dry_run:
        print("DRY_RUN=1", flush=True)
        return 0

    selected: list[str] = []
    if args.apply_all:
        selected = missing
    else:
        for permission in missing:
            answer = input(f"Add to global settings? {permission} [y/n/a/q] ").strip().lower()
            if answer in {"a", "all"}:
                selected.extend(permission for permission in missing if permission not in selected)
                break
            if answer in {"q", "quit"}:
                break
            if answer in {"y", "yes"}:
                selected.append(permission)

    if not selected:
        print("ADDED=0", flush=True)
        return 0

    allow.extend(permission for permission in selected if permission not in existing)
    permissions["allow"] = sorted(str(item) for item in allow)
    write_json(global_settings, global_data)
    print(f"ADDED={len(selected)}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
