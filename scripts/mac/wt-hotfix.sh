#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKBENCH_ROOT="${WORKBENCH_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$WORKBENCH_ROOT/scripts/worktrees/wt_hotfix.py" "$@"
fi
exec python "$WORKBENCH_ROOT/scripts/worktrees/wt_hotfix.py" "$@"
