#!/usr/bin/env bash
#
# setup-skills.sh — Create symlinks from ~/.claude/skills/ to workbench/.agents/skills/
#
# Usage: bash setup-skills.sh [--remove]
#   --remove    Remove symlinks instead of creating them

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$(cd "$SCRIPT_DIR/../skills" && pwd)"
SKILLS_DST="$HOME/.claude/skills"

SKILLS=(
    cut-release
    hotfix
    worktree-feature-create
    worktrees
)

remove_mode=false
if [[ "${1:-}" == "--remove" ]]; then
    remove_mode=true
fi

if $remove_mode; then
    echo "Removing skill symlinks..."
    for skill in "${SKILLS[@]}"; do
        target="$SKILLS_DST/$skill"
        if [[ -L "$target" ]]; then
            rm "$target"
            echo "  Removed: $target"
        elif [[ -e "$target" ]]; then
            echo "  Skipped: $target (not a symlink, won't remove)"
        else
            echo "  Already gone: $target"
        fi
    done
    echo "Done."
    exit 0
fi

# Create destination directory
mkdir -p "$SKILLS_DST"

echo "Setting up skill symlinks..."
echo "  Source: $SKILLS_SRC"
echo "  Target: $SKILLS_DST"
echo ""

for skill in "${SKILLS[@]}"; do
    src="$SKILLS_SRC/$skill"
    dst="$SKILLS_DST/$skill"

    if [[ ! -d "$src" ]]; then
        echo "  ERROR: Source not found: $src"
        continue
    fi

    if [[ -L "$dst" ]]; then
        # Existing symlink — update it
        rm "$dst"
        ln -s "$src" "$dst"
        echo "  Updated: $skill -> $src"
    elif [[ -e "$dst" ]]; then
        # Something else exists (directory, file) — don't clobber
        echo "  SKIPPED: $dst already exists and is not a symlink"
    else
        ln -s "$src" "$dst"
        echo "  Created: $skill -> $src"
    fi
done

echo ""
echo "Done. Skills available:"
for skill in "${SKILLS[@]}"; do
    if [[ -L "$SKILLS_DST/$skill" ]]; then
        echo "  /$skill"
    fi
done
