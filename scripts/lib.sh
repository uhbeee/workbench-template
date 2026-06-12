#!/usr/bin/env bash
# lib.sh — Shared cross-platform functions for workbench scripts
# Source this file: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$REPO_ROOT/config.yaml"

# ─── Platform Detection ────────────────────────────────────────────────────

is_windows() {
  [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]
}

is_mac() {
  [[ "$(uname -s)" == "Darwin" ]]
}

# ─── Path Conversion ───────────────────────────────────────────────────────

# Convert MSYS/Git Bash path to Windows-friendly path for PowerShell
to_win_path() {
  if command -v cygpath &>/dev/null; then
    cygpath -m "$1"
  else
    echo "$1"
  fi
}

# ─── Junction/Symlink Helpers ──────────────────────────────────────────────

# Check if a path is a junction or symlink
is_link() {
  local path="$1"
  if is_windows; then
    local win_path
    win_path="$(to_win_path "$path")"
    local link_type
    link_type=$(powershell.exe -NoProfile -Command "(Get-Item '$win_path' -ErrorAction SilentlyContinue).LinkType" 2>/dev/null | tr -d '\r\n')
    [[ "$link_type" == "Junction" || "$link_type" == "SymbolicLink" ]]
  else
    [[ -L "$path" ]]
  fi
}

# Get the target of a junction/symlink
link_target() {
  local path="$1"
  if is_windows; then
    local win_path
    win_path="$(to_win_path "$path")"
    powershell.exe -NoProfile -Command "(Get-Item '$win_path' -ErrorAction SilentlyContinue).Target" 2>/dev/null | tr -d '\r\n'
  else
    readlink "$path"
  fi
}

# Create a directory junction (Windows) or symlink (Unix)
create_dir_link() {
  local src="$1" dst="$2"
  if is_windows; then
    local win_src win_dst
    win_src="$(to_win_path "$src")"
    win_dst="$(to_win_path "$dst")"
    powershell.exe -NoProfile -Command "New-Item -ItemType Junction -Path '$win_dst' -Target '$win_src' | Out-Null" 2>&1
  else
    ln -s "$src" "$dst"
  fi
}

# Create a file symlink (on Windows, requires admin privileges)
create_file_link() {
  local src="$1" dst="$2"
  if is_windows; then
    local win_src win_dst
    win_src="$(to_win_path "$src")"
    win_dst="$(to_win_path "$dst")"
    powershell.exe -NoProfile -Command "New-Item -ItemType SymbolicLink -Path '$win_dst' -Target '$win_src' | Out-Null" 2>&1
  else
    ln -s "$src" "$dst"
  fi
}

# Remove a junction/symlink safely
remove_link() {
  local path="$1"
  if is_windows; then
    local win_path
    win_path="$(to_win_path "$path")"
    # Junctions must be removed as directory, not recursively
    powershell.exe -NoProfile -Command "
      \$item = Get-Item '$win_path' -ErrorAction SilentlyContinue
      if (\$item.LinkType) {
        \$item.Delete()
      }
    " 2>/dev/null
  else
    rm -f "$path"
  fi
}

# Return true when two directory paths resolve to the same physical location.
same_physical_dir() {
  local left="$1" right="$2"
  [[ -d "$left" && -d "$right" ]] || return 1

  local left_real right_real
  left_real="$(cd "$left" && pwd -P)"
  right_real="$(cd "$right" && pwd -P)"
  [[ "$left_real" == "$right_real" ]]
}

# Worktree skills share one canonical scripts implementation. Each skill keeps a
# skill-local scripts/ entry for Agent Skills compatibility.
worktree_skill_script_link_skills() {
  printf '%s\n' \
    cut-release \
    hotfix \
    sync-permissions \
    worktree-feature-create \
    worktrees \
    worktree-review-create \
    worktree-sync \
    worktree-remove \
    worktree-migrate
}

ensure_worktree_skill_script_links() {
  local target_abs="$REPO_ROOT/scripts/worktrees"
  local target_rel="../../../scripts/worktrees"
  local failures=0

  if [[ ! -d "$target_abs" ]]; then
    fail "scripts/worktrees missing; cannot create worktree skill script links"
    return 1
  fi

  while IFS= read -r skill; do
    [[ -n "$skill" ]] || continue

    local skill_dir="$REPO_ROOT/.agents/skills/$skill"
    local link_path="$skill_dir/scripts"

    if [[ ! -d "$skill_dir" ]]; then
      warn "$skill/scripts skipped — skill directory missing"
      failures=$((failures + 1))
      continue
    fi

    if is_link "$link_path"; then
      if same_physical_dir "$link_path" "$target_abs"; then
        pass "$skill/scripts → scripts/worktrees"
        continue
      fi

      remove_link "$link_path"
    elif [[ -e "$link_path" ]]; then
      rm -rf "$link_path"
    fi

    if is_windows; then
      create_dir_link "$target_abs" "$link_path" >/dev/null
    else
      ln -s "$target_rel" "$link_path"
    fi

    if same_physical_dir "$link_path" "$target_abs"; then
      pass "$skill/scripts → scripts/worktrees"
    else
      fail "$skill/scripts could not be linked to scripts/worktrees"
      failures=$((failures + 1))
    fi
  done < <(worktree_skill_script_link_skills)

  [[ $failures -eq 0 ]]
}

# ─── Config Helpers ────────────────────────────────────────────────────────

# Check if config.yaml exists
require_config() {
  if [[ ! -f "$CONFIG" ]]; then
    echo "Error: config.yaml not found at $CONFIG"
    echo "Copy config.example.yaml to config.yaml and fill in your values."
    exit 1
  fi
}

# Parse a simple list from config.yaml (no yq dependency)
# Usage: parse_yaml_list "skills.global" → outputs one item per line
parse_yaml_list() {
  local key="$1"
  # Handle nested keys like "skills.global" → find "global:" under "skills:"
  local parts
  IFS='.' read -ra parts <<< "$key"

  if [[ ${#parts[@]} -eq 1 ]]; then
    sed -n "/^${parts[0]}:/,/^[^ ]/p" "$CONFIG" \
      | grep '^ *- ' \
      | sed 's/^ *- *//; s/ *#.*//' \
      | tr -d '"' \
      | tr -d "'"
  elif [[ ${#parts[@]} -eq 2 ]]; then
    sed -n "/^${parts[0]}:/,/^[^ ]/p" "$CONFIG" \
      | sed -n "/^ *${parts[1]}:/,/^$/p" \
      | grep '^ *- ' \
      | sed 's/^ *- *//; s/ *#.*//' \
      | tr -d '"' \
      | tr -d "'"
  fi
}

# Parse a simple scalar from config.yaml
# Usage: parse_yaml_value "worktrees.root" → outputs the value
parse_yaml_value() {
  local key="$1"
  local parts
  IFS='.' read -ra parts <<< "$key"

  if [[ ${#parts[@]} -eq 1 ]]; then
    grep "^${parts[0]}:" "$CONFIG" | head -1 | sed 's/^[^:]*: *//; s/ *#.*//' | tr -d '"' | tr -d "'"
  elif [[ ${#parts[@]} -eq 2 ]]; then
    sed -n "/^${parts[0]}:/,/^[^ ]/p" "$CONFIG" \
      | grep "^ *${parts[1]}:" | head -1 \
      | sed 's/^[^:]*: *//; s/ *#.*//' | tr -d '"' | tr -d "'"
  fi
}

# ─── Global Skills Helper ─────────────────────────────────────────────────

SKILLS_GLOBAL_FILE="$REPO_ROOT/skills-global.yaml"

# Parse the global skills list, preferring skills-global.yaml (committed),
# falling back to config.yaml skills.global (legacy).
parse_global_skills() {
  if [[ -f "$SKILLS_GLOBAL_FILE" ]]; then
    grep '^ *- ' "$SKILLS_GLOBAL_FILE" \
      | sed 's/^ *- *//; s/ *#.*//' \
      | tr -d '"' \
      | tr -d "'"
  else
    parse_yaml_list "skills.global"
  fi
}

# ─── Output Helpers ────────────────────────────────────────────────────────

# Colored output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

pass()  { echo -e "  ${GREEN}[PASS]${NC}  $1"; }
warn()  { echo -e "  ${YELLOW}[WARN]${NC}  $1"; }
fail()  { echo -e "  ${RED}[FAIL]${NC}  $1"; }
info()  { echo -e "  ${BLUE}[INFO]${NC}  $1"; }
header() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }
