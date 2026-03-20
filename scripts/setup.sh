#!/usr/bin/env bash
# setup.sh — One-command interactive setup for the workbench
# Windows entry: scripts/windows/bin/setup.cmd
#
# Creates junctions, symlinks, shell profile entries, global skills, and context dirs.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "Workbench Setup"

# ─── Step 1: Platform detection ────────────────────────────────────────────
echo ""
if is_windows; then
  info "Platform: Windows (Git Bash)"
elif is_mac; then
  info "Platform: macOS"
else
  info "Platform: Linux"
fi

# Check required tools
for tool in git python3; do
  if command -v "$tool" &>/dev/null; then
    pass "$tool found: $(command -v "$tool")"
  else
    warn "$tool not found (some features may not work)"
  fi
done

# ─── Step 2: Config bootstrap ──────────────────────────────────────────────
header "Configuration"

if [[ ! -f "$CONFIG" ]]; then
  info "No config.yaml found. Creating from template..."
  cp "$REPO_ROOT/config.example.yaml" "$CONFIG"
  echo ""
  echo "  Created config.yaml from template."
  echo "  Edit it later to customize: $CONFIG"
  echo ""

  # Prompt for minimal config
  read -rp "  Your name: " user_name
  read -rp "  Your organization: " user_org

  if [[ -n "$user_name" ]]; then
    sed -i "s/name: \"Jane Smith\"/name: \"$user_name\"/" "$CONFIG"
  fi
  if [[ -n "$user_org" ]]; then
    sed -i "s/organization: \"Acme Corp\"/organization: \"$user_org\"/" "$CONFIG"
  fi

  # Set workbench root to this repo's working tree
  sed -i "s|__WORKBENCH_ROOT__|$REPO_ROOT|" "$CONFIG"

  pass "Config created (edit config.yaml for full customization)"
else
  pass "config.yaml exists"
fi

# Ensure workbench.root is set (handles existing configs missing it)
if ! grep -q "^workbench:" "$CONFIG"; then
  sed -i "1i\\
# --- Workbench Root ---\\
workbench:\\
  root: \"$REPO_ROOT\"\\
" "$CONFIG"
  pass "Added workbench.root to existing config"
elif grep -q "__WORKBENCH_ROOT__" "$CONFIG"; then
  sed -i "s|__WORKBENCH_ROOT__|$REPO_ROOT|" "$CONFIG"
  pass "Set workbench.root to $REPO_ROOT"
else
  pass "workbench.root already configured"
fi

# ─── Step 3: Create junctions and symlinks ─────────────────────────────────
header "Junctions & Symlinks"

# Ensure target directories exist
mkdir -p "$REPO_ROOT/.claude"
mkdir -p "$REPO_ROOT/.cursor"

# Directory junctions (no admin needed on Windows)
declare -A DIR_JUNCTIONS=(
  [".claude/agents"]=".agents/agents"
  [".claude/hooks"]=".agents/hooks"
  [".claude/skills"]=".agents/skills"
  [".cursor/agents"]=".agents/agents"
  [".cursor/hooks"]=".agents/hooks"
  [".cursor/skills"]=".agents/skills"
)

for dst in "${!DIR_JUNCTIONS[@]}"; do
  src="${DIR_JUNCTIONS[$dst]}"
  full_dst="$REPO_ROOT/$dst"
  full_src="$REPO_ROOT/$src"

  if is_link "$full_dst"; then
    pass "$dst (already linked)"
  elif [[ -d "$full_dst" ]]; then
    # Remove the directory if it's not a junction (was copied by git)
    rm -rf "$full_dst"
    if create_dir_link "$full_src" "$full_dst"; then
      pass "$dst → $src"
    else
      fail "$dst (could not create junction)"
    fi
  else
    if create_dir_link "$full_src" "$full_dst"; then
      pass "$dst → $src"
    else
      fail "$dst (could not create junction)"
    fi
  fi
done

# .cursor/mcp.json junction (file junction on Windows needs special handling — use dir junction to parent)
cursor_mcp_dst="$REPO_ROOT/.cursor/mcp.json"
cursor_mcp_src="$REPO_ROOT/.agents/mcp.json"
if [[ -f "$cursor_mcp_src" ]]; then
  if is_link "$cursor_mcp_dst"; then
    pass ".cursor/mcp.json (already linked)"
  else
    # For mcp.json, just copy on Windows since file junctions are tricky
    if is_windows; then
      cp "$cursor_mcp_src" "$cursor_mcp_dst"
      pass ".cursor/mcp.json (copied)"
    else
      ln -sf "$cursor_mcp_src" "$cursor_mcp_dst"
      pass ".cursor/mcp.json → .agents/mcp.json"
    fi
  fi
fi

# File symlink: .claude/CLAUDE.md → ../AGENTS.md
claude_md_dst="$REPO_ROOT/.claude/CLAUDE.md"
agents_md_src="$REPO_ROOT/AGENTS.md"
if is_link "$claude_md_dst"; then
  pass ".claude/CLAUDE.md (already linked)"
elif [[ -f "$claude_md_dst" ]]; then
  rm "$claude_md_dst"
  if create_file_link "$agents_md_src" "$claude_md_dst"; then
    pass ".claude/CLAUDE.md → AGENTS.md"
  else
    fail ".claude/CLAUDE.md — file symlink failed"
    if is_windows; then
      echo ""
      warn "File symlinks on Windows require admin privileges."
      echo "  Run this in an admin PowerShell:"
      echo "  New-Item -ItemType SymbolicLink -Path '$(to_win_path "$claude_md_dst")' -Target '$(to_win_path "$agents_md_src")'"
      echo ""
    fi
  fi
else
  if create_file_link "$agents_md_src" "$claude_md_dst"; then
    pass ".claude/CLAUDE.md → AGENTS.md"
  else
    fail ".claude/CLAUDE.md — file symlink failed"
    if is_windows; then
      echo ""
      warn "File symlinks on Windows require admin privileges."
      echo "  Run this in an admin PowerShell:"
      echo "  New-Item -ItemType SymbolicLink -Path '$(to_win_path "$claude_md_dst")' -Target '$(to_win_path "$agents_md_src")'"
      echo ""
    fi
  fi
fi

# ─── Step 4: Shell profile setup ──────────────────────────────────────────
header "Shell Profile"

if is_windows; then
  profile_file="$HOME/.bashrc"
  profile_line="source \"$REPO_ROOT/scripts/windows/wt-profile.sh\""
  path_line="export PATH=\"$REPO_ROOT/scripts/windows/bin:\$PATH\""

  if [[ -f "$profile_file" ]] && grep -qF "wt-profile.sh" "$profile_file"; then
    pass "wt-profile.sh already sourced in ~/.bashrc"
  else
    echo "" >> "$profile_file"
    echo "# Workbench: worktree functions and navigation" >> "$profile_file"
    echo "$profile_line" >> "$profile_file"
    pass "Added wt-profile.sh to ~/.bashrc"
  fi

  if [[ -f "$profile_file" ]] && grep -qF "scripts/windows/bin" "$profile_file"; then
    pass "bin/ already in PATH"
  else
    echo "$path_line" >> "$profile_file"
    pass "Added scripts/windows/bin/ to PATH"
  fi

  # Generate wt-config.sh
  wt_config="$REPO_ROOT/scripts/windows/wt-config.sh"
  worktree_root=$(parse_yaml_value "worktrees.root" 2>/dev/null || echo "C:/worktrees-SeekOut")
  cat > "$wt_config" << WTEOF
#!/bin/bash
# Auto-generated by setup.sh — do not edit
export WORKTREE_ROOT="$worktree_root"
export WORKTREE_SCRIPTS="$REPO_ROOT/scripts/windows"
export WORKBENCH_ROOT="$REPO_ROOT"
WTEOF
  pass "Generated scripts/windows/wt-config.sh"

  # Generate wt-config.cmd for Windows CMD wrappers
  wt_config_cmd="$REPO_ROOT/scripts/windows/bin/wt-config.cmd"
  win_worktree_root=$(cygpath -w "$worktree_root" 2>/dev/null || echo "$worktree_root")
  win_scripts=$(cygpath -w "$REPO_ROOT/scripts/windows" 2>/dev/null || to_win_path "$REPO_ROOT/scripts/windows")
  win_workbench=$(cygpath -w "$REPO_ROOT" 2>/dev/null || to_win_path "$REPO_ROOT")
  cat > "$wt_config_cmd" << WTCMDEOF
@echo off
REM Auto-generated by setup.sh — do not edit
REM
REM All wt-*.cmd wrappers call this file. It provides:
REM   WORKTREE_ROOT    — root directory for all worktrees
REM   WORKTREE_SCRIPTS — path to scripts/windows (bash scripts)
REM   WORKBENCH_ROOT   — path to the workbench repo root
REM   SCRIPTS_PATH     — alias for WORKTREE_SCRIPTS (used by .cmd wrappers)
REM   GIT_BASH         — path to bash executable
REM
REM To create a new .cmd wrapper: wt-new-cmd <script-name> [--workdir]
set "WORKTREE_ROOT=$win_worktree_root"
set "WORKTREE_SCRIPTS=$win_scripts"
set "WORKBENCH_ROOT=$win_workbench"
set "SCRIPTS_PATH=$win_scripts"
set "GIT_BASH="
if exist "C:\\Program Files\\Git\\bin\\bash.exe" set "GIT_BASH=C:\\Program Files\\Git\\bin\\bash.exe"
if not defined GIT_BASH (where bash >nul 2>&1 && set "GIT_BASH=bash")
if not defined GIT_BASH (echo Error: Git Bash not found. Install Git for Windows. & exit /b 1)
WTCMDEOF
  pass "Generated scripts/windows/bin/wt-config.cmd"

elif is_mac; then
  profile_file="$HOME/.zshrc"
  profile_line="source \"$REPO_ROOT/scripts/mac/wt-profile.zsh\""

  if [[ -f "$profile_file" ]] && grep -qF "wt-profile.zsh" "$profile_file"; then
    pass "wt-profile.zsh already sourced in ~/.zshrc"
  else
    echo "" >> "$profile_file"
    echo "# Workbench: worktree functions and navigation" >> "$profile_file"
    echo "$profile_line" >> "$profile_file"
    pass "Added wt-profile.zsh to ~/.zshrc"
  fi
fi

# ─── Step 4b: Claude aliases ──────────────────────────────────────────────
header "Claude Aliases"

# Bash/Zsh aliases
if is_windows; then
  alias_file="$HOME/.bashrc"
else
  alias_file="$HOME/.zshrc"
fi

if [[ -f "$alias_file" ]] && grep -qF "alias cc=" "$alias_file"; then
  pass "Claude aliases in $(basename "$alias_file") already configured"
else
  cat >> "$alias_file" << 'CLAUDE_ALIASES'

# Claude Code shortcuts (added by workbench setup)
alias cc='claude'
alias ccd='claude --dangerously-skip-permissions'
CLAUDE_ALIASES
  pass "Added cc and ccd aliases to $(basename "$alias_file")"
fi

# PowerShell aliases (Windows only)
if is_windows; then
  ps_profile=$(powershell.exe -NoProfile -Command 'Write-Host $PROFILE' 2>/dev/null | tr -d '\r\n')
  if [[ -n "$ps_profile" ]]; then
    # Convert Windows path to MSYS path for file operations
    ps_profile_unix=$(cygpath -u "$ps_profile" 2>/dev/null || echo "$ps_profile")
    ps_profile_dir=$(dirname "$ps_profile_unix")

    if [[ -f "$ps_profile_unix" ]] && grep -qF "Set-Alias cc claude" "$ps_profile_unix"; then
      pass "Claude aliases in PowerShell profile already configured"
    else
      mkdir -p "$ps_profile_dir"
      cat >> "$ps_profile_unix" << 'PS_ALIASES'

# Claude Code shortcuts (added by workbench setup)
Set-Alias cc claude
function ccd { claude --dangerously-skip-permissions @args }
PS_ALIASES
      pass "Added cc and ccd aliases to PowerShell profile"
    fi
  else
    warn "Could not determine PowerShell profile path — skipping PS aliases"
  fi
fi

# ─── Step 5: Global skills ────────────────────────────────────────────────
header "Global Skills"

SKILLS_SRC="$REPO_ROOT/.agents/skills"
SKILLS_DST="$HOME/.claude/skills"
mkdir -p "$SKILLS_DST"

mapfile -t GLOBAL_SKILLS < <(parse_global_skills 2>/dev/null)

if [[ ${#GLOBAL_SKILLS[@]} -eq 0 ]]; then
  info "No global skills configured (check skills-global.yaml or config.yaml skills.global)"
else
  created=0
  skipped=0
  for skill in "${GLOBAL_SKILLS[@]}"; do
    src="$SKILLS_SRC/$skill"
    dst="$SKILLS_DST/$skill"

    if [[ ! -d "$src" ]]; then
      warn "$skill — not found in .agents/skills/"
      continue
    fi

    if is_link "$dst"; then
      skipped=$((skipped + 1))
      continue
    elif [[ -e "$dst" ]]; then
      skipped=$((skipped + 1))
      continue
    fi

    if create_dir_link "$src" "$dst"; then
      created=$((created + 1))
    else
      warn "$skill — could not create link"
    fi
  done
  pass "Global skills: $created linked, $skipped already set up"
fi

# ─── Step 5b: Workbench root pointer ─────────────────────────────────
header "Workbench Root Pointer"

wb_root_file="$HOME/.claude/workbench-root"
mkdir -p "$HOME/.claude"
echo "$REPO_ROOT" > "$wb_root_file"
pass "Wrote workbench root to ~/.claude/workbench-root"

# ─── Step 6: Context directories ──────────────────────────────────────────
header "Context Directories"

for dir in context/active context/archive context/plans context/notes; do
  mkdir -p "$REPO_ROOT/$dir"
done
pass "Context directories ready"

# ─── Step 7: Pre-commit hook ─────────────────────────────────────────────
header "Pre-commit Hook"

hook_src="$REPO_ROOT/.agents/hooks/check-unlisted-skills.sh"
git_dir=$(cd "$REPO_ROOT" && git rev-parse --git-dir 2>/dev/null)
hook_dst="$git_dir/hooks/pre-commit"

if [[ -f "$hook_src" ]]; then
  mkdir -p "$git_dir/hooks"
  if [[ -f "$hook_dst" ]]; then
    if grep -q "check-unlisted-skills" "$hook_dst"; then
      pass "Pre-commit hook already installed"
    else
      echo "" >> "$hook_dst"
      echo "# Workbench: warn about unlisted skills" >> "$hook_dst"
      echo "bash \"$hook_src\"" >> "$hook_dst"
      pass "Appended skill check to existing pre-commit hook"
    fi
  else
    cp "$hook_src" "$hook_dst"
    chmod +x "$hook_dst"
    pass "Pre-commit hook installed"
  fi
else
  warn "Hook source not found: $hook_src"
fi

# ─── Step 8: Skill validation ────────────────────────────────────────────
header "Skill Validation"

if [[ -f "$REPO_ROOT/scripts/validate-skills.sh" ]]; then
  bash "$REPO_ROOT/scripts/validate-skills.sh" || warn "Skill validation found issues (see above)"
else
  info "validate-skills.sh not found — skipping skill validation"
fi

# ─── Step 9: Run doctor ───────────────────────────────────────────────────
header "Verification"
echo ""

if [[ -f "$REPO_ROOT/scripts/doctor.sh" ]]; then
  bash "$REPO_ROOT/scripts/doctor.sh"
else
  info "doctor.sh not yet created — skipping verification"
fi

echo ""
echo "Setup complete! Restart your shell or run: source ~/.bashrc"
