#!/usr/bin/env bash
#
# Symlink portable workbench skills to global AI-tool skill directories
# so they're available in every Claude Code and Codex project.
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
SKILL_TARGET_DIRS=()
while IFS= read -r target_dir; do
  [[ -n "$target_dir" ]] || continue
  SKILL_TARGET_DIRS+=("$target_dir")
done < <(parse_skill_targets)

# ponytail: while-read instead of mapfile, macOS ships bash 3.2
SKILLS=()
while IFS= read -r skill; do
  [[ -n "$skill" ]] || continue
  SKILLS+=("$skill")
done < <(parse_effective_global_skills 2>/dev/null)

if [[ -f "$SKILLS_LOCAL_FILE" ]]; then
  echo "Local selection active (skills-local.yaml): installing ${#SKILLS[@]} skill(s)."
  echo ""
fi

if [[ ${#SKILLS[@]} -eq 0 ]]; then
  echo "No global skills configured (check skills-global.yaml or config.yaml skills.global)."
  exit 0
fi

echo "Workbench skill script links:"
ensure_worktree_skill_script_links
echo ""

total_created=0
total_skipped=0
total_missing=0
total_pruned=0

# ponytail: newline-delimited membership string, bash 3.2 has no associative arrays
CONFIGURED_SKILLS=$'\n'
for skill in "${SKILLS[@]}"; do
  CONFIGURED_SKILLS+="$skill"$'\n'
done

prune_stale_workbench_skill_links() {
  local skills_dst="$1"
  local pruned=0

  shopt -s nullglob
  for dst in "$skills_dst"/*; do
    local skill_name target
    skill_name="$(basename "$dst")"

    if [[ "$CONFIGURED_SKILLS" == *$'\n'"$skill_name"$'\n'* ]]; then
      continue
    fi
    if ! is_link "$dst"; then
      continue
    fi

    target="$(link_target "$dst")"
    if [[ "$target" == "$SKILLS_SRC/"* ]]; then
      remove_link "$dst"
      echo "  PRUNED   $skill_name (removed stale Workbench skill link)"
      pruned=$((pruned + 1))
    fi
  done
  shopt -u nullglob

  return "$pruned"
}

for i in "${!SKILL_TARGET_DIRS[@]}"; do
  skills_dst="${SKILL_TARGET_DIRS[$i]}"
  label="$skills_dst"

  mkdir -p "$skills_dst"

  created=0
  skipped=0
  missing=0
  pruned=0

  echo "$label global skills:"
  prune_stale_workbench_skill_links "$skills_dst" || pruned=$?
  for skill in "${SKILLS[@]}"; do
    src="$SKILLS_SRC/$skill"
    dst="$skills_dst/$skill"

    if [[ ! -d "$src" ]]; then
      echo "  MISSING  $skill (not found in .agents/skills/)"
      missing=$((missing + 1))
      continue
    fi

    if is_link "$dst"; then
      if [[ -d "$dst" ]]; then
        echo "  OK       $skill (already linked)"
        skipped=$((skipped + 1))
        continue
      fi

      remove_link "$dst"
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

  echo "  Done: $created linked, $skipped unchanged, $missing missing, $pruned pruned"
  echo ""

  total_created=$((total_created + created))
  total_skipped=$((total_skipped + skipped))
  total_missing=$((total_missing + missing))
  total_pruned=$((total_pruned + pruned))
done

echo "All done: $total_created linked, $total_skipped unchanged, $total_missing missing, $total_pruned pruned"
