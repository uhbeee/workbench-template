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

# ─── Cross-platform sed -i ──────────────────────────────────────────────────

# macOS sed requires -i '' (empty backup ext), GNU sed uses -i alone.
sed_i() {
  if is_mac; then
    sed -i '' "$@"
  else
    sed -i "$@"
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
