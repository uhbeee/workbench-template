#!/usr/bin/env bash
# template-sync.sh — Sync safe content to the public template repo
# Uses an inverted allowlist: only explicitly listed paths are synced.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ALLOWLIST="$REPO_ROOT/scripts/template-allowlist.yaml"
TEMPLATE_DIR=""  # Will be set below

header "Template Sync"

# ─── Find template repo ───────────────────────────────────────────────────

# Check for template remote or a separate template clone
template_remote=$(git -C "$REPO_ROOT" remote get-url template 2>/dev/null || echo "")

if [[ -z "$template_remote" ]]; then
  fail "No 'template' remote configured."
  echo "  Add one with: git remote add template <url>"
  exit 1
fi

# Look for a local template clone/worktree
# Default: sibling directory named workbench-template
TEMPLATE_DIR="$(dirname "$REPO_ROOT")/workbench-template"

if [[ ! -d "$TEMPLATE_DIR/.git" ]]; then
  info "Template repo not found at $TEMPLATE_DIR"
  read -rp "  Clone template repo to $TEMPLATE_DIR? [y/N] " confirm
  if [[ "$confirm" == [yY] ]]; then
    git clone "$template_remote" "$TEMPLATE_DIR"
    pass "Template repo cloned"
  else
    fail "Cannot sync without a local template repo"
    exit 1
  fi
fi

# ─── Parse allowlist ──────────────────────────────────────────────────────

if [[ ! -f "$ALLOWLIST" ]]; then
  fail "Allowlist not found: $ALLOWLIST"
  exit 1
fi

ALLOWED_PATHS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && ALLOWED_PATHS+=("$line")
done < <(
  grep '^ *- ' "$ALLOWLIST" \
    | sed 's/^ *- *//; s/ *#.*//' \
    | tr -d '"' \
    | tr -d "'"
)

# ─── Check for unlisted skills ────────────────────────────────────────────
header "Checking for unlisted skills"

unlisted=()
for skill_dir in "$REPO_ROOT/.agents/skills"/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name=$(basename "$skill_dir")
  skill_path=".agents/skills/$skill_name/"

  found=false
  for allowed in "${ALLOWED_PATHS[@]}"; do
    if [[ "$allowed" == *"$skill_name"* ]]; then
      found=true
      break
    fi
  done

  if ! $found; then
    unlisted+=("$skill_name")
    warn "Skill NOT in allowlist (will be excluded): $skill_name"
  fi
done

if [[ ${#unlisted[@]} -eq 0 ]]; then
  pass "All skills are listed in allowlist"
fi

# ─── Confirm ──────────────────────────────────────────────────────────────
echo ""
echo "Will sync ${#ALLOWED_PATHS[@]} paths to: $TEMPLATE_DIR"
if [[ ${#unlisted[@]} -gt 0 ]]; then
  echo "  (${#unlisted[@]} skill(s) excluded: ${unlisted[*]})"
fi
read -rp "  Proceed? [y/N] " confirm
[[ "$confirm" == [yY] ]] || exit 0

# ─── Sync ─────────────────────────────────────────────────────────────────
header "Syncing"

# Clear template contents (except .git/)
find "$TEMPLATE_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + 2>/dev/null

for path in "${ALLOWED_PATHS[@]}"; do
  src="$REPO_ROOT/$path"
  dst="$TEMPLATE_DIR/$path"

  if [[ ! -e "$src" ]]; then
    warn "Source not found: $path"
    continue
  fi

  # Create parent directory
  mkdir -p "$(dirname "$dst")"

  if [[ -d "$src" ]]; then
    cp -rL "$src" "$dst"  # -L follows symlinks/junctions
  else
    cp -L "$src" "$dst"
  fi
  pass "$path"
done

# ─── Sensitive pattern scan ───────────────────────────────────────────────
header "Security Scan"

sensitive_patterns=(
  "seekout\.com"
  "zipstorm"
  "api[_-]?key"
  "secret[_-]?key"
  "password\s*[:=]"
  "Bearer\s+[A-Za-z0-9]"
)

found_sensitive=false
for pattern in "${sensitive_patterns[@]}"; do
  matches=$(grep -rli "$pattern" "$TEMPLATE_DIR" --include='*.md' --include='*.yaml' --include='*.yml' --include='*.sh' --include='*.py' --include='*.json' 2>/dev/null | grep -v '.git/' | grep -v 'template-sync\.sh' || true)
  if [[ -n "$matches" ]]; then
    found_sensitive=true
    fail "Pattern '$pattern' found in:"
    echo "$matches" | while read -r f; do echo "    $f"; done
  fi
done

if $found_sensitive; then
  echo ""
  fail "Sensitive content detected! Review before pushing."
  exit 1
else
  pass "No sensitive patterns detected"
fi

# ─── Commit and push ─────────────────────────────────────────────────────
echo ""
read -rp "  Commit and push to template? [y/N] " confirm
if [[ "$confirm" == [yY] ]]; then
  cd "$TEMPLATE_DIR"
  git add -A

  if git diff --cached --quiet; then
    info "No changes to commit"
  else
    git commit -m "Sync from workbench $(date +%Y-%m-%d)"
    git push
    pass "Template updated and pushed"
  fi
fi

echo ""
echo "Done!"
