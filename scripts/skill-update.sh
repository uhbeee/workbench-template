#!/usr/bin/env bash
# skill-update.sh — Pull upstream changes for skills recorded in skills-lock.yaml.
#
# Usage:
#   bash scripts/skill-update.sh              # check + apply clean updates for all
#   bash scripts/skill-update.sh <name> ...   # only these skills
#   bash scripts/skill-update.sh <name> --force   # overwrite local modifications
#
# Behavior per skill:
#   - upstream unchanged                → up to date
#   - upstream changed, local pristine  → update applied, lock ref bumped
#   - upstream changed, local modified  → skipped with a diff (use --force to overwrite)

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILLS_DIR="$REPO_ROOT/.agents/skills"
LOCK_FILE="$REPO_ROOT/skills-lock.yaml"

force_flag=false
requested=()
for arg in "$@"; do
  case "$arg" in
    --force) force_flag=true ;;
    *)       requested+=("$arg") ;;
  esac
done

if [[ ! -f "$LOCK_FILE" ]]; then
  fail "No skills-lock.yaml found. Import skills with scripts/skill-add.sh first."
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# lock_field <name> <field>
lock_field() {
  sed -n "/^  $1:/,/^  [^ ]/p" "$LOCK_FILE" | grep "^    $2:" | head -1 | sed 's/^[^:]*: *//'
}

lock_names() {
  grep -E '^  [^ ]+:' "$LOCK_FILE" | sed 's/^  //; s/:.*//'
}

# fetch_tarball <user/repo> <ref> — echoes extracted root dir
fetch_tarball() {
  local user_repo="$1" ref="$2"
  local dl_dir
  dl_dir=$(mktemp -d "$TMP_DIR/fetch.XXXXXX")

  if command -v gh &>/dev/null; then
    gh api "repos/${user_repo}/tarball/${ref}" > "$dl_dir/repo.tar.gz" 2>/dev/null || return 1
  elif command -v curl &>/dev/null; then
    curl -fsL "https://api.github.com/repos/${user_repo}/tarball/${ref}" -o "$dl_dir/repo.tar.gz" || return 1
  else
    fail "Neither gh nor curl available for downloading"
    exit 1
  fi

  tar -xzf "$dl_dir/repo.tar.gz" -C "$dl_dir" 2>/dev/null
  find "$dl_dir" -maxdepth 1 -mindepth 1 -type d | head -1
}

# update_lock_ref <name> <ref>
update_lock_ref() {
  local name="$1" ref="$2" tmp
  tmp=$(mktemp)
  awk -v name="$name" -v ref="$ref" '
    $0 == "  " name ":" { in_entry = 1; print; next }
    in_entry && /^  [^ ]/ { in_entry = 0 }
    in_entry && /^    ref:/ { print "    ref: " ref; next }
    { print }
  ' "$LOCK_FILE" > "$tmp"
  mv "$tmp" "$LOCK_FILE"
}

wants() {
  [[ ${#requested[@]} -eq 0 ]] && return 0
  local r
  for r in "${requested[@]}"; do
    [[ "$r" == "$1" ]] && return 0
  done
  return 1
}

header "Skill Update"

updated=0
skipped=0
uptodate=0
failed=0

while IFS= read -r name; do
  wants "$name" || continue

  repo=$(lock_field "$name" repo)
  branch=$(lock_field "$name" branch)
  path=$(lock_field "$name" path)
  ref=$(lock_field "$name" ref)

  if [[ -z "$repo" || "$repo" == local* ]]; then
    info "$name: local import, nothing to update"
    continue
  fi

  local_dir="$SKILLS_DIR/$name"
  if [[ ! -d "$local_dir" ]]; then
    warn "$name: in lock file but not installed — run skill-add.sh to reinstall"
    skipped=$((skipped + 1))
    continue
  fi

  head_root=$(fetch_tarball "$repo" "$branch") || { fail "$name: could not fetch $repo@$branch"; failed=$((failed + 1)); continue; }
  new_ref="${head_root##*-}"
  new_dir="$head_root/$path"

  if [[ ! -d "$new_dir" ]]; then
    warn "$name: path '$path' no longer exists upstream in $repo@$branch"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ "$new_ref" == "$ref" ]] || diff -rq "$local_dir" "$new_dir" >/dev/null 2>&1; then
    pass "$name: up to date ($new_ref)"
    [[ "$new_ref" != "$ref" ]] && update_lock_ref "$name" "$new_ref"
    uptodate=$((uptodate + 1))
    continue
  fi

  # Upstream changed. Is the local copy pristine relative to the locked ref?
  modified=false
  if base_root=$(fetch_tarball "$repo" "$ref") && [[ -d "$base_root/$path" ]]; then
    diff -rq "$base_root/$path" "$local_dir" >/dev/null 2>&1 || modified=true
  else
    warn "$name: could not fetch locked ref $ref; treating local copy as modified"
    modified=true
  fi

  if $modified && ! $force_flag; then
    warn "$name: locally modified AND upstream changed — skipping (re-run with '$name --force' to overwrite)"
    echo "  Upstream diff (local → $repo@$new_ref):"
    diff -ru "$local_dir" "$new_dir" 2>/dev/null | head -60 | sed 's/^/  /'
    skipped=$((skipped + 1))
    continue
  fi

  rm -rf "$local_dir"
  cp -r "$new_dir" "$local_dir"
  update_lock_ref "$name" "$new_ref"
  pass "$name: updated $ref → $new_ref"
  updated=$((updated + 1))
done < <(lock_names)

echo ""
echo "Done: $updated updated, $uptodate up to date, $skipped skipped, $failed failed"
