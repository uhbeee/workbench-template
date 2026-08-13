#!/usr/bin/env bash
# skill-add.sh — Import skills from a GitHub URL, local path, or registry
# into .agents/skills (the single source of truth for every harness).
#
# Usage:
#   bash scripts/skill-add.sh <source> [--project] [--force] [--all] [--skills a,b]
#   bash scripts/skill-add.sh <repo-url> --list-skills
#   bash scripts/skill-add.sh --list
#
# Sources:
#   Skill URL: https://github.com/user/repo/tree/main/path/to/skill
#   Repo URL:  https://github.com/user/repo  (enumerates all skills in repo)
#   Path:      /path/to/skill-dir (must contain SKILL.md)
#   Registry:  name (looked up in scripts/skill-registry.yaml)
#
# Scope: imports are GLOBAL by default (registered in skills-global.yaml and
# linked into every harness dir from skill-targets.yaml). Use --project to
# keep a skill available only inside this repo.
#
# Every remote import is recorded in skills-lock.yaml (repo, branch, path,
# ref) so scripts/skill-update.sh can pull upstream changes later.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILLS_DIR="$REPO_ROOT/.agents/skills"
REGISTRY="$REPO_ROOT/scripts/skill-registry.yaml"
LOCK_FILE="$REPO_ROOT/skills-lock.yaml"

# Parse flags
global_flag=true
force_flag=false
list_flag=false
list_skills_flag=false
all_flag=false
skills_filter=""
source_arg=""

prev_flag=""
for arg in "$@"; do
  if [[ "$prev_flag" == "--skills" ]]; then
    skills_filter="$arg"
    prev_flag=""
    continue
  fi
  case "$arg" in
    --global)      global_flag=true ;;
    --project)     global_flag=false ;;
    --force)       force_flag=true ;;
    --list)        list_flag=true ;;
    --list-skills) list_skills_flag=true ;;
    --all)         all_flag=true ;;
    --skills)      prev_flag="--skills" ;;
    --skills=*)    skills_filter="${arg#--skills=}" ;;
    *)             source_arg="$arg" ;;
  esac
done

# ─── List registry ─────────────────────────────────────────────────────────
if $list_flag; then
  header "Skill Registry"
  if [[ -f "$REGISTRY" ]]; then
    echo ""
    grep -E '^\s+\w+:' "$REGISTRY" | sed 's/://; s/^ */  /'
  else
    warn "Registry file not found: $REGISTRY"
  fi
  exit 0
fi

if [[ -z "$source_arg" ]]; then
  echo "Usage: skill-add <source> [--project] [--force] [--all] [--skills a,b]"
  echo "       skill-add <repo-url> --list-skills"
  echo "       skill-add --list"
  echo ""
  echo "Source can be:"
  echo "  Skill URL:  https://github.com/user/repo/tree/main/path/to/skill"
  echo "  Repo URL:   https://github.com/user/repo"
  echo "  Local path: /path/to/skill-dir"
  echo "  Registry:   skill-name"
  exit 1
fi

# ─── Lock file ─────────────────────────────────────────────────────────────

# record_lock <name> <repo> <branch> <path> <ref>
record_lock() {
  local name="$1" repo="$2" branch="$3" path="$4" ref="$5"

  if [[ ! -f "$LOCK_FILE" ]]; then
    {
      echo "# Skills Lock"
      echo "#"
      echo "# Provenance of imported skills — managed by scripts/skill-add.sh."
      echo "# scripts/skill-update.sh uses these entries to pull upstream changes."
      echo ""
      echo "skills:"
    } > "$LOCK_FILE"
  fi

  # Drop any existing entry for this skill, then append the fresh one.
  local tmp
  tmp=$(mktemp)
  awk -v name="$name" '
    $0 == "  " name ":" { skip = 1; next }
    skip && /^  [^ ]/    { skip = 0 }
    skip                 { next }
    { print }
  ' "$LOCK_FILE" > "$tmp"
  mv "$tmp" "$LOCK_FILE"

  {
    echo "  $name:"
    echo "    repo: $repo"
    echo "    branch: $branch"
    echo "    path: $path"
    echo "    ref: $ref"
  } >> "$LOCK_FILE"
}

# ─── Install helpers ───────────────────────────────────────────────────────

INSTALLED_NAMES=()

# install_from_dir <src-dir> — copy a skill dir into .agents/skills
install_from_dir() {
  local src="$1"
  local name
  name=$(basename "$src")
  local dst="$SKILLS_DIR/$name"

  if [[ ! -f "$src/SKILL.md" ]]; then
    fail "No SKILL.md found in $src"
    return 1
  fi

  if [[ -d "$dst" ]] && ! $force_flag; then
    fail "Skill '$name' already exists. Use --force to overwrite."
    return 1
  fi

  rm -rf "$dst"
  cp -r "$src" "$dst"
  pass "Installed skill: $name"

  if head -5 "$dst/SKILL.md" | grep -q "^description:"; then
    info "$(head -5 "$dst/SKILL.md" | grep "^description:" | sed 's/^description: *//' | cut -c1-100)"
  fi

  INSTALLED_NAMES+=("$name")
}

# ─── GitHub fetch ──────────────────────────────────────────────────────────

TMP_DIR=""
cleanup() { [[ -n "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# fetch_tarball <user/repo> <ref> <dest-var-name>
# Downloads and extracts a repo tarball; echoes the extracted root dir.
fetch_tarball() {
  local user_repo="$1" ref="$2"
  local dl_dir
  dl_dir=$(mktemp -d "$TMP_DIR/fetch.XXXXXX")

  if command -v gh &>/dev/null; then
    gh api "repos/${user_repo}/tarball/${ref}" > "$dl_dir/repo.tar.gz" 2>/dev/null \
      || { fail "Could not download ${user_repo}@${ref} via gh"; return 1; }
  elif command -v curl &>/dev/null; then
    curl -fsL "https://api.github.com/repos/${user_repo}/tarball/${ref}" -o "$dl_dir/repo.tar.gz" \
      || { fail "Could not download ${user_repo}@${ref} via curl"; return 1; }
  else
    fail "Neither gh nor curl available for downloading"
    return 1
  fi

  tar -xzf "$dl_dir/repo.tar.gz" -C "$dl_dir" 2>/dev/null
  find "$dl_dir" -maxdepth 1 -mindepth 1 -type d | head -1
}

# default_branch <user/repo> — best effort, falls back to main
default_branch() {
  local user_repo="$1" branch=""
  if command -v gh &>/dev/null; then
    branch=$(gh api "repos/${user_repo}" --jq .default_branch 2>/dev/null || true)
  elif command -v curl &>/dev/null; then
    branch=$(curl -fsL "https://api.github.com/repos/${user_repo}" 2>/dev/null \
      | grep '"default_branch"' | head -1 | sed 's/.*: *"//; s/".*//')
  fi
  echo "${branch:-main}"
}

# list_skill_dirs <root> — relative paths of dirs containing SKILL.md
list_skill_dirs() {
  local root="$1"
  ( cd "$root" && find . -name SKILL.md -not -path '*/node_modules/*' \
      | sed 's|^\./||; s|/SKILL.md$||' | sort )
}

install_from_github() {
  local url="$1"
  local stripped="${url#https://github.com/}"
  stripped="${stripped%/}"
  local user_repo branch sub_path
  user_repo=$(echo "$stripped" | cut -d'/' -f1-2)

  if [[ "$stripped" == */tree/* ]]; then
    local after_tree="${stripped#${user_repo}/tree/}"
    branch=$(echo "$after_tree" | cut -d'/' -f1)
    sub_path=$(echo "$after_tree" | cut -d'/' -f2-)
    [[ "$sub_path" == "$branch" ]] && sub_path=""
  else
    branch=$(default_branch "$user_repo")
    sub_path=""
  fi

  info "Fetching $user_repo (branch: $branch)..."
  local extracted
  extracted=$(fetch_tarball "$user_repo" "$branch") || exit 1
  # GitHub tarball roots look like user-repo-<sha>; the suffix is the ref.
  local ref="${extracted##*-}"

  local scan_root="$extracted"
  [[ -n "$sub_path" ]] && scan_root="$extracted/$sub_path"

  if [[ ! -d "$scan_root" ]]; then
    fail "Path not found in repo: $sub_path"
    exit 1
  fi

  # Single-skill URL: the path itself is a skill.
  if [[ -f "$scan_root/SKILL.md" ]]; then
    local name
    name=$(basename "$scan_root")
    install_from_dir "$scan_root" && record_lock "$name" "$user_repo" "$branch" "${sub_path:-$name}" "$ref"
    return
  fi

  # Repo/directory URL: enumerate skills beneath it.
  local rel_paths=()
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    rel_paths+=("$rel")
  done < <(list_skill_dirs "$scan_root")

  if [[ ${#rel_paths[@]} -eq 0 ]]; then
    fail "No SKILL.md found anywhere under $url"
    exit 1
  fi

  if $list_skills_flag; then
    header "Skills in $user_repo${sub_path:+/$sub_path} (branch: $branch)"
    local rel
    for rel in "${rel_paths[@]}"; do
      echo "$rel"
    done
    exit 0
  fi

  if ! $all_flag && [[ -z "$skills_filter" ]]; then
    fail "Repo contains ${#rel_paths[@]} skills. Re-run with --list-skills to enumerate,"
    echo "  then --skills <a,b,...> to pick, or --all to import everything."
    exit 1
  fi

  local rel name wanted matched
  for rel in "${rel_paths[@]}"; do
    name=$(basename "$rel")

    if ! $all_flag; then
      matched=false
      IFS=',' read -ra wanted <<< "$skills_filter"
      for w in "${wanted[@]}"; do
        w="$(echo "$w" | sed 's/^ *//; s/ *$//')"
        [[ "$w" == "$name" || "$w" == "$rel" ]] && matched=true
      done
      $matched || continue
    fi

    local full_path="$rel"
    [[ -n "$sub_path" ]] && full_path="$sub_path/$rel"
    if install_from_dir "$scan_root/$rel"; then
      record_lock "$name" "$user_repo" "$branch" "$full_path" "$ref"
    fi
  done

  if [[ ${#INSTALLED_NAMES[@]} -eq 0 ]]; then
    fail "No skills matched --skills $skills_filter"
    exit 1
  fi
}

install_from_registry() {
  local name="$1"

  if [[ ! -f "$REGISTRY" ]]; then
    fail "Registry not found: $REGISTRY"
    exit 1
  fi

  local url
  url=$(sed -n "/^ *${name}:/,/^ *[^ ]/p" "$REGISTRY" | grep "url:" | head -1 | sed 's/.*url: *//; s/ *#.*//' | tr -d '"' | tr -d "'")

  if [[ -z "$url" ]]; then
    fail "Skill '$name' not found in registry. Use --list to see available skills."
    exit 1
  fi

  install_from_github "$url"
}

# ─── Main ──────────────────────────────────────────────────────────────────
header "Skill Import"
TMP_DIR=$(mktemp -d)

if [[ "$source_arg" == https://github.com/* ]]; then
  install_from_github "$source_arg"
elif [[ -d "$source_arg" ]]; then
  install_from_dir "$source_arg" || exit 1
else
  install_from_registry "$source_arg"
fi

# ─── Global registration ───────────────────────────────────────────────────
if $global_flag && [[ ${#INSTALLED_NAMES[@]} -gt 0 ]]; then
  echo ""
  SKILLS_GLOBAL_FILE="$REPO_ROOT/skills-global.yaml"

  for name in "${INSTALLED_NAMES[@]}"; do
    if [[ -f "$SKILLS_GLOBAL_FILE" ]]; then
      if ! grep -q "^ *- *${name}\$" "$SKILLS_GLOBAL_FILE"; then
        echo "  - $name" >> "$SKILLS_GLOBAL_FILE"
        info "Added '$name' to skills-global.yaml"
      fi
    fi

    src="$SKILLS_DIR/$name"
    while IFS= read -r skills_dst; do
      [[ -n "$skills_dst" ]] || continue
      mkdir -p "$skills_dst"
      dst="$skills_dst/$name"

      if is_link "$dst"; then
        [[ -d "$dst" ]] && continue
        remove_link "$dst"
      elif [[ -e "$dst" ]]; then
        warn "Link skipped: $dst already exists and is not a link"
        continue
      fi

      create_dir_link "$src" "$dst"
      pass "Linked: $dst"
    done < <(parse_skill_targets)
  done
fi

echo ""
if [[ ${#INSTALLED_NAMES[@]} -gt 0 ]]; then
  scope="globally"
  $global_flag || scope="in this project only"
  echo "Done! Installed ${#INSTALLED_NAMES[@]} skill(s) $scope: ${INSTALLED_NAMES[*]}"
fi
