#!/usr/bin/env bash
#
# Symlink portable workbench skills to ~/.claude/skills/
# so they're available in every Claude Code project.
#
# Reads from skills-global.yaml (committed), falling back to
# config.yaml skills.global (legacy/gitignored).
# Re-run after adding/removing entries.
#
# On Windows (Git Bash/MSYS2), uses directory junctions via PowerShell
# since Git Bash ln -s creates copies instead of real symlinks.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILLS_SRC="$REPO_ROOT/.agents/skills"
SKILLS_DST="$HOME/.claude/skills"

SKILLS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && SKILLS+=("$line")
done < <(parse_global_skills 2>/dev/null)

if [[ ${#SKILLS[@]} -eq 0 ]]; then
  echo "No global skills configured (check skills-global.yaml or config.yaml skills.global)."
  exit 0
fi

mkdir -p "$SKILLS_DST"

created=0
skipped=0
missing=0

for skill in "${SKILLS[@]}"; do
  src="$SKILLS_SRC/$skill"
  dst="$SKILLS_DST/$skill"

  if [[ ! -d "$src" ]]; then
    echo "  MISSING  $skill (not found in .agents/skills/)"
    missing=$((missing + 1))
    continue
  fi

  if is_link "$dst"; then
    echo "  OK       $skill (already linked)"
    skipped=$((skipped + 1))
    continue
  elif [[ -e "$dst" ]]; then
    echo "  SKIP     $skill (non-link already exists at $dst)"
    skipped=$((skipped + 1))
    continue
  fi

  if create_dir_link "$src" "$dst"; then
    echo "  LINKED   $skill"
    created=$((created + 1))
  else
    echo "  FAILED   $skill (could not create link)"
    missing=$((missing + 1))
  fi
done

echo ""
echo "Done: $created linked, $skipped unchanged, $missing missing"
