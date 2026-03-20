#!/usr/bin/env bash
# skill-add.sh — Import a skill from GitHub URL, local path, or registry
#
# Usage:
#   bash scripts/skill-add.sh <source> [--global] [--force]
#   bash scripts/skill-add.sh --list
#
# Sources:
#   URL:      https://github.com/user/repo/tree/main/.claude/skills/commit
#   Path:     /path/to/skill-dir (must contain SKILL.md)
#   Registry: name (looked up in scripts/skill-registry.yaml)

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILLS_DIR="$REPO_ROOT/.agents/skills"
REGISTRY="$REPO_ROOT/scripts/skill-registry.yaml"

# Parse flags
global_flag=false
force_flag=false
list_flag=false
source_arg=""

for arg in "$@"; do
  case "$arg" in
    --global) global_flag=true ;;
    --force)  force_flag=true ;;
    --list)   list_flag=true ;;
    *)        source_arg="$arg" ;;
  esac
done

# ─── List registry ─────────────────────────────────────────────────────────
if $list_flag; then
  header "Skill Registry"
  if [[ -f "$REGISTRY" ]]; then
    echo ""
    # Parse and display registry entries
    grep -E '^\s+\w+:' "$REGISTRY" | sed 's/://; s/^ */  /'
  else
    warn "Registry file not found: $REGISTRY"
  fi
  exit 0
fi

if [[ -z "$source_arg" ]]; then
  echo "Usage: skill-add <source> [--global] [--force]"
  echo "       skill-add --list"
  echo ""
  echo "Source can be:"
  echo "  GitHub URL:  https://github.com/user/repo/tree/main/.claude/skills/name"
  echo "  Local path:  /path/to/skill-dir"
  echo "  Registry:    skill-name"
  exit 1
fi

# ─── Detect source type ───────────────────────────────────────────────────

install_from_local() {
  local src="$1"
  local name
  name=$(basename "$src")
  local dst="$SKILLS_DIR/$name"

  if [[ ! -f "$src/SKILL.md" ]]; then
    fail "No SKILL.md found in $src"
    exit 1
  fi

  if [[ -d "$dst" ]] && ! $force_flag; then
    fail "Skill '$name' already exists. Use --force to overwrite."
    exit 1
  fi

  if [[ -d "$dst" ]]; then
    rm -rf "$dst"
  fi

  cp -r "$src" "$dst"
  pass "Installed skill: $name"

  # Show skill info
  if head -5 "$dst/SKILL.md" | grep -q "^description:"; then
    info "$(head -5 "$dst/SKILL.md" | grep "^description:" | sed 's/^description: *//')"
  fi

  echo "$name"
}

install_from_github() {
  local url="$1"

  # Parse GitHub URL: https://github.com/user/repo/tree/branch/path/to/skill
  local repo_part branch_part path_part

  # Remove https://github.com/ prefix
  local stripped="${url#https://github.com/}"

  # Extract user/repo
  local user_repo
  user_repo=$(echo "$stripped" | cut -d'/' -f1-2)

  # Extract branch and path (after /tree/)
  local after_tree
  after_tree=$(echo "$stripped" | sed "s|^${user_repo}/tree/||")
  local branch
  branch=$(echo "$after_tree" | cut -d'/' -f1)
  local skill_path
  skill_path=$(echo "$after_tree" | cut -d'/' -f2-)

  local skill_name
  skill_name=$(basename "$skill_path")

  info "Fetching $skill_name from $user_repo (branch: $branch)..."

  # Create temp dir
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap "rm -rf '$tmp_dir'" EXIT

  # Download via GitHub API (tarball)
  local api_url="https://api.github.com/repos/${user_repo}/tarball/${branch}"

  if command -v gh &>/dev/null; then
    gh api "repos/${user_repo}/tarball/${branch}" > "$tmp_dir/repo.tar.gz" 2>/dev/null
  elif command -v curl &>/dev/null; then
    curl -sL "$api_url" -o "$tmp_dir/repo.tar.gz"
  else
    fail "Neither gh nor curl available for downloading"
    exit 1
  fi

  # Extract just the skill directory
  tar -xzf "$tmp_dir/repo.tar.gz" -C "$tmp_dir" 2>/dev/null

  # Find the extracted directory (GitHub tarballs have a random prefix)
  local extracted_dir
  extracted_dir=$(find "$tmp_dir" -maxdepth 1 -type d ! -name "$(basename "$tmp_dir")" | head -1)

  local skill_src="$extracted_dir/$skill_path"

  if [[ ! -d "$skill_src" ]]; then
    fail "Skill path not found in repo: $skill_path"
    exit 1
  fi

  install_from_local "$skill_src"
}

install_from_registry() {
  local name="$1"

  if [[ ! -f "$REGISTRY" ]]; then
    fail "Registry not found: $REGISTRY"
    exit 1
  fi

  # Look up URL in registry
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

installed_name=""

if [[ "$source_arg" == https://github.com/* ]]; then
  installed_name=$(install_from_github "$source_arg")
elif [[ -d "$source_arg" ]]; then
  installed_name=$(install_from_local "$source_arg")
else
  installed_name=$(install_from_registry "$source_arg")
fi

# Handle --global flag
if $global_flag && [[ -n "$installed_name" ]]; then
  echo ""
  info "Adding '$installed_name' to global skills..."

  # Add to skills-global.yaml (committed), falling back to config.yaml (legacy)
  SKILLS_GLOBAL_FILE="$REPO_ROOT/skills-global.yaml"
  if [[ -f "$SKILLS_GLOBAL_FILE" ]]; then
    if ! grep -q "^ *- *${installed_name}$" "$SKILLS_GLOBAL_FILE"; then
      # Append before the last line (keeps file tidy) or just append
      echo "  - $installed_name" >> "$SKILLS_GLOBAL_FILE"
    fi
  elif grep -q "^skills:" "$CONFIG" 2>/dev/null; then
    if ! grep -q "^ *global:" "$CONFIG" 2>/dev/null; then
      sed_i '/^skills:/a\
  global:\
    - '"$installed_name" "$CONFIG"
    else
      if ! grep -q "^ *- *${installed_name}$" "$CONFIG"; then
        sed_i "/^ *global:/a\\
    - $installed_name" "$CONFIG"
      fi
    fi
  else
    echo "" >> "$CONFIG"
    echo "skills:" >> "$CONFIG"
    echo "  global:" >> "$CONFIG"
    echo "    - $installed_name" >> "$CONFIG"
  fi

  # Create global junction
  local src="$SKILLS_DIR/$installed_name"
  local dst="$HOME/.claude/skills/$installed_name"
  mkdir -p "$HOME/.claude/skills"

  if ! is_link "$dst" && [[ ! -e "$dst" ]]; then
    create_dir_link "$src" "$dst"
    pass "Global junction created: ~/.claude/skills/$installed_name"
  fi
fi

echo ""
echo "Done! The skill is now available as /$installed_name"
