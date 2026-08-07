#!/usr/bin/env bash
# doctor.sh — Diagnose the workbench environment
# Checks config, junctions, worktrees, shell profile, cross-platform tools, and MCP.
# Exit code: 0 if all pass, 1 if any fail.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

json_mode=false
[[ "${1:-}" == "--json" ]] && json_mode=true

failures=0
warnings=0

check_pass()  { pass "$1"; }
check_warn()  { warn "$1"; warnings=$((warnings + 1)); }
check_fail()  { fail "$1"; failures=$((failures + 1)); }

# ─── 1. Config ─────────────────────────────────────────────────────────────
header "Config"

if [[ -f "$CONFIG" ]]; then
  check_pass "config.yaml exists"

  # Check required keys
  for key in "user:" "github:" "jira:" "slack:" "capacity:"; do
    if grep -q "^$key" "$CONFIG"; then
      check_pass "config.yaml has $key section"
    else
      check_warn "config.yaml missing $key section"
    fi
  done
else
  check_fail "config.yaml not found — run: cp config.example.yaml config.yaml"
fi

# ─── 2. Junctions ─────────────────────────────────────────────────────────
header "Junctions & Symlinks"

# Check directory junctions
for junction in .claude/agents .claude/hooks .claude/skills .cursor/agents .cursor/hooks .cursor/skills; do
  full_path="$REPO_ROOT/$junction"
  if is_link "$full_path"; then
    # Verify target exists
    target=$(link_target "$full_path")
    if [[ -d "$full_path" ]]; then
      check_pass "$junction → resolves OK"
    else
      check_fail "$junction → target missing (recreate with: bash scripts/setup.sh)"
    fi
  elif [[ -d "$full_path" ]]; then
    check_warn "$junction exists as regular directory (not a junction — run setup.sh)"
  else
    check_fail "$junction missing (run: bash scripts/setup.sh)"
  fi
done

# Check CLAUDE.md symlink
claude_md="$REPO_ROOT/.claude/CLAUDE.md"
if is_link "$claude_md"; then
  check_pass ".claude/CLAUDE.md → symlink OK"
elif [[ -f "$claude_md" ]]; then
  check_warn ".claude/CLAUDE.md exists as regular file (not a symlink — run setup.sh)"
else
  check_fail ".claude/CLAUDE.md missing (run: bash scripts/setup.sh)"
fi

# Check global skills
check_global_skill_dir() {
  local label="$1"
  local skills_dst="$2"

  if [[ ! -d "$skills_dst" ]]; then
    check_warn "$label global skills directory does not exist: $skills_dst (run setup.sh)"
    return
  fi

  local broken=0
  local missing=0

  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    [[ -d "$REPO_ROOT/.agents/skills/$skill" ]] || continue

    local skill_link="$skills_dst/$skill"
    if [[ ! -e "$skill_link" && ! -L "$skill_link" ]]; then
      check_warn "$label global skill missing: $skill (run setup.sh)"
      missing=$((missing + 1))
    elif is_link "$skill_link" && [[ ! -d "$skill_link" ]]; then
      check_fail "$label global skill $skill — broken link"
      broken=$((broken + 1))
    fi
  done < <(parse_global_skills 2>/dev/null || true)

  if [[ $broken -eq 0 && $missing -eq 0 ]]; then
    check_pass "$label global skills — configured links present"
  elif [[ $broken -eq 0 ]]; then
    check_pass "$label global skills — no broken links"
  fi
}

check_global_skill_dir "Claude Code" "$HOME/.claude/skills"
check_global_skill_dir "Codex" "$HOME/.codex/skills"

# Check skill-local scripts links used by worktree skills.
worktree_scripts_target="$REPO_ROOT/scripts/worktrees"
worktree_script_link_failures=0

while IFS= read -r skill; do
  [[ -n "$skill" ]] || continue

  skill_dir="$REPO_ROOT/.agents/skills/$skill"
  skill_scripts="$skill_dir/scripts"

  if [[ ! -d "$skill_dir" ]]; then
    check_fail "$skill missing (required for worktree skill script link)"
    worktree_script_link_failures=$((worktree_script_link_failures + 1))
  elif ! is_link "$skill_scripts"; then
    check_fail "$skill/scripts is not a link to scripts/worktrees (run setup.sh)"
    worktree_script_link_failures=$((worktree_script_link_failures + 1))
  elif same_physical_dir "$skill_scripts" "$worktree_scripts_target"; then
    check_pass "$skill/scripts → scripts/worktrees"
  else
    check_fail "$skill/scripts link target is wrong or missing (run setup.sh)"
    worktree_script_link_failures=$((worktree_script_link_failures + 1))
  fi
done < <(worktree_skill_script_link_skills)

if [[ $worktree_script_link_failures -eq 0 ]]; then
  check_pass "Workbench worktree skill script links are valid"
fi

# Check workbench root pointers used by global skills.
for pointer in "$HOME/.claude/workbench-root" "$HOME/.codex/workbench-root"; do
  if [[ ! -f "$pointer" ]]; then
    check_warn "$pointer missing (run setup.sh)"
  elif [[ "$(cat "$pointer")" == "$REPO_ROOT" ]]; then
    check_pass "$pointer points to this workbench"
  else
    check_warn "$pointer points elsewhere: $(cat "$pointer")"
  fi
done

# ─── 3. Worktrees ─────────────────────────────────────────────────────────
header "Worktrees"

worktree_root=$(parse_yaml_value "worktrees.root" 2>/dev/null || echo "")
worktree_root="${worktree_root/#\~/$HOME}"
if [[ -n "$worktree_root" ]]; then
  if [[ -d "$worktree_root" ]]; then
    check_pass "Worktree root exists: $worktree_root"

    # Check for stale worktrees
    stale=0
    for repo_git in "$worktree_root"/*.git; do
      [[ -d "$repo_git" ]] || continue
      while IFS= read -r line; do
        if [[ "$line" == *"prunable"* ]]; then
          stale=$((stale + 1))
        fi
      done < <(git -C "$repo_git/main" worktree list --porcelain 2>/dev/null | grep prunable || true)
    done

    if [[ $stale -gt 0 ]]; then
      check_warn "$stale stale worktree(s) found (run wt-cleanup)"
    else
      check_pass "No stale worktrees"
    fi
  else
    check_fail "Worktree root does not exist: $worktree_root"
  fi
else
  check_warn "worktrees.root not configured in config.yaml"
fi

# ─── 4. Shell Profile ─────────────────────────────────────────────────────
header "Shell Profile"

if is_windows; then
  profile="$HOME/.bashrc"
  if [[ -f "$profile" ]] && grep -qF "wt-profile.sh" "$profile"; then
    check_pass "wt-profile.sh sourced in ~/.bashrc"
  else
    check_warn "wt-profile.sh not in ~/.bashrc (run setup.sh)"
  fi

  if [[ -f "$profile" ]] && grep -qF "scripts/windows/bin" "$profile"; then
    check_pass "bin/ in PATH via ~/.bashrc"
  else
    check_warn "scripts/windows/bin/ not in PATH (run setup.sh)"
  fi
elif is_mac; then
  profile="$HOME/.zshrc"
  if [[ -f "$profile" ]] && grep -qF "wt-profile.zsh" "$profile"; then
    check_pass "wt-profile.zsh sourced in ~/.zshrc"
  else
    check_warn "wt-profile.zsh not in ~/.zshrc (run setup.sh)"
  fi
fi

# ─── 5. Cross-Platform Tools ──────────────────────────────────────────────
header "Tools"

for tool in git python3 bash; do
  if command -v "$tool" &>/dev/null; then
    check_pass "$tool: $(command -v "$tool")"
  else
    check_fail "$tool not found"
  fi
done

if is_windows; then
  if command -v powershell.exe &>/dev/null; then
    check_pass "PowerShell available"
  else
    check_fail "PowerShell not found (required for junctions on Windows)"
  fi
fi

# ─── 6. MCP ───────────────────────────────────────────────────────────────
header "MCP & Hooks"

settings_local="$REPO_ROOT/.claude/settings.local.json"
if [[ -f "$settings_local" ]]; then
  check_pass "settings.local.json exists"
else
  check_warn "settings.local.json missing (Claude Code will prompt for permissions)"
fi

# Check hook scripts exist
for hook in "$REPO_ROOT/.agents/hooks"/*.py; do
  [[ -f "$hook" ]] || continue
  check_pass "Hook: $(basename "$hook")"
done

# ─── Summary ───────────────────────────────────────────────────────────────
echo ""
if [[ $failures -eq 0 && $warnings -eq 0 ]]; then
  echo -e "${GREEN}All checks passed!${NC}"
elif [[ $failures -eq 0 ]]; then
  echo -e "${YELLOW}$warnings warning(s), no failures${NC}"
else
  echo -e "${RED}$failures failure(s), $warnings warning(s)${NC}"
fi

exit $([[ $failures -eq 0 ]] && echo 0 || echo 1)
