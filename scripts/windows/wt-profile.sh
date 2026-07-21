#!/bin/bash
# wt-profile.sh - Source this in your .bashrc or .zshrc
# Add this line to your shell profile:
#   source "C:/worktrees/workbench/scripts/windows/wt-profile.sh"

# Load generated config if available, otherwise use defaults
SCRIPT_DIR_PROFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR_PROFILE/wt-config.sh" ]; then
    source "$SCRIPT_DIR_PROFILE/wt-config.sh"
else
    export WORKTREE_ROOT="C:/worktrees"
    export WORKTREE_SCRIPTS="$SCRIPT_DIR_PROFILE"
    export WORKBENCH_ROOT="$(cd "$SCRIPT_DIR_PROFILE/../.." && pwd)"
fi

_wt_python() {
    if command -v py >/dev/null 2>&1; then
        echo "py -3"
    elif command -v python >/dev/null 2>&1; then
        echo python
    else
        echo python3
    fi
}

_wt_run_python() {
    local script="$1"
    shift
    # shellcheck disable=SC2046
    $(_wt_python) "$WORKBENCH_ROOT/scripts/worktrees/$script" "$@"
}

# ============================================================
# Core Worktree Functions
# ============================================================

# Initialize a new repo for worktree workflow
wt-init() {
    bash "$WORKTREE_SCRIPTS/wt-init.sh" "$@"
}

# Create a feature worktree
wt-feature() {
    local output rc worktree_path
    output="$(_wt_run_python wt_feature.py --workdir "$PWD" "$@" 2>&1)"
    rc=$?
    printf '%s\n' "$output"
    # Auto-cd to the new worktree
    if [ "$rc" -eq 0 ]; then
        worktree_path=$(printf '%s\n' "$output" | awk -F= '/^WORKTREE_PATH=/{print $2; exit}')
        [ -n "$worktree_path" ] && [ -d "$worktree_path" ] && cd "$worktree_path" 2>/dev/null || true
    fi
    return "$rc"
}

# Quick PR review
wt-review() {
    local output rc worktree_path
    output="$(_wt_run_python wt_review.py --workdir "$PWD" "$@" 2>&1)"
    rc=$?
    printf '%s\n' "$output"
    if [ "$rc" -eq 0 ]; then
        worktree_path=$(printf '%s\n' "$output" | awk -F= '/^WORKTREE_PATH=/{print $2; exit}')
        [ -n "$worktree_path" ] && [ -d "$worktree_path" ] && cd "$worktree_path" 2>/dev/null || true
    fi
    return "$rc"
}

# Done with review
wt-review-done() {
    _wt_run_python wt_review_done.py --workdir "$PWD" "$@"
}

# Status across all repos
wt-status() {
    _wt_run_python wt_status.py "$@"
}

# Cleanup stale worktrees
wt-cleanup() {
    _wt_run_python wt_cleanup.py "$@"
}

# Migrate existing repo or clone from URL to worktree structure
wt-migrate() {
    _wt_run_python wt_migrate.py "$@"
}

# Remove a worktree
wt-remove() {
    local repo_root rc
    repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null || echo "$WORKTREE_ROOT")
    _wt_run_python wt_remove.py --workdir "$PWD" "$@"
    rc=$?
    [ "$rc" -eq 0 ] && [ ! -d "$PWD" ] && cd "$repo_root" 2>/dev/null || true
    return "$rc"
}

# ============================================================
# Claude Launchers (cc/ccd are global aliases set up by setup.sh)
# ============================================================

# Navigate to worktree and launch claude
wtc() { wtn "$@" && claude; }

# Navigate to worktree and launch claude --dangerously-skip-permissions
wtcd() { wtn "$@" && claude --dangerously-skip-permissions; }

# ============================================================
# Aliases
# ============================================================

alias wtrm='wt-remove'
alias wtg='wtn'

# ============================================================
# Quick Navigation
# ============================================================

# Jump to worktree root
wtgo() {
    cd "$WORKTREE_ROOT"
}

# Jump to a specific repo
wtr() {
    local repo=$1
    if [ -z "$repo" ]; then
        echo "Available repos:"
        ls -1 "$WORKTREE_ROOT" | grep '\.git$' | sed 's/\.git$//'
        return
    fi
    cd "$WORKTREE_ROOT/${repo}.git"
}

# Jump to develop worktree of current or specified repo
wtd() {
    local repo=$1
    if [ -z "$repo" ]; then
        # Try to detect from current location
        local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
        if [ -n "$repo_root" ]; then
            cd "$repo_root/develop" 2>/dev/null || echo "No develop worktree"
            return
        fi
    fi
    cd "$WORKTREE_ROOT/${repo}.git/develop" 2>/dev/null || echo "No develop worktree for $repo"
}

# Jump to main worktree
wtm() {
    local repo=$1
    if [ -z "$repo" ]; then
        local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
        if [ -n "$repo_root" ]; then
            cd "$repo_root/main" 2>/dev/null || echo "No main worktree"
            return
        fi
    fi
    cd "$WORKTREE_ROOT/${repo}.git/main" 2>/dev/null || echo "No main worktree for $repo"
}

# List worktrees in current repo
wtl() {
    git worktree list
}

# Interactive navigation (use -c to launch Claude Code after)
wtn() {
    # Handle wtn - (go to last worktree)
    if [ "$1" = "-" ]; then
        if [ -f ~/.wt_last ]; then
            local last_dir=$(cat ~/.wt_last)
            if [ -d "$last_dir" ]; then
                echo "$(pwd)" > ~/.wt_last
                cd "$last_dir"
                echo "$(pwd)"
                return 0
            else
                echo "Last worktree no longer exists: $last_dir"
                return 1
            fi
        else
            echo "No previous worktree"
            return 1
        fi
    fi
    # Save current dir before navigating
    echo "$(pwd)" > ~/.wt_last
    source "$WORKTREE_SCRIPTS/wtn.sh" "$@"
}

# ============================================================
# Release & Hotfix Workflow
# ============================================================

# Create a release branch
wt-release() {
    _wt_run_python wt_release.py --workdir "$PWD" "$@"
}


wt-hotfix() {
    local output rc worktree_path
    output="$(_wt_run_python wt_hotfix.py --workdir "$PWD" "$@" 2>&1)"
    rc=$?
    printf '%s\n' "$output"
    if [ "$rc" -eq 0 ]; then
        worktree_path=$(printf '%s\n' "$output" | awk -F= '/^WORKTREE_PATH=/{print $2; exit}')
        [ -n "$worktree_path" ] && [ -d "$worktree_path" ] && cd "$worktree_path" 2>/dev/null || true
    fi
    return "$rc"
}

wt-hotfix-done() {
    _wt_run_python wt_hotfix_done.py --workdir "$PWD" "$@"
}

wt-hotfix-pr() {
    local output rc worktree_path
    output="$(_wt_run_python wt_hotfix_pr.py --workdir "$PWD" "$@" 2>&1)"
    rc=$?
    printf '%s\n' "$output"
    if [ "$rc" -eq 0 ]; then
        worktree_path=$(printf '%s\n' "$output" | awk -F= '/^WORKTREE_PATH=/{print $2; exit}')
        [ -n "$worktree_path" ] && [ -d "$worktree_path" ] && cd "$worktree_path" 2>/dev/null || true
    fi
    return "$rc"
}

# Sync current branch with develop (or another branch)
wt-sync() {
    _wt_run_python wt_sync.py --workdir "$PWD" "$@"
}

wt-sync-permissions() {
    _wt_run_python wt_sync_permissions.py --workdir "$PWD" "$@"
}

# ============================================================
# Tab Completion (Bash)
# ============================================================

_wtr_completions() {
    local repos=$(ls -1 "$WORKTREE_ROOT" 2>/dev/null | grep '\.git$' | sed 's/\.git$//')
    COMPREPLY=($(compgen -W "$repos" -- "${COMP_WORDS[1]}"))
}

_wt_remove_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"

    # Complete flags
    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-f --force -d --delete-branch -k --keep-branch -y --yes --stale" -- "$cur"))
        return
    fi

    # Complete worktree names
    local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
    [ -z "$repo_root" ] && return
    local names=""
    for kind in _feature _hotfix _review; do
        [ -d "$repo_root/$kind" ] || continue
        for d in "$repo_root/$kind"/*/; do
            [ -d "$d" ] && names+="$(basename "$d") "
        done
    done
    COMPREPLY=($(compgen -W "$names" -- "$cur"))
}

_wtn_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "-c --code -" -- "$cur"))
        return
    fi
}

_wt_status_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "--dirty" -- "$cur"))
        return
    fi
    local repos=$(ls -1 "$WORKTREE_ROOT" 2>/dev/null | grep '\.git$' | sed 's/\.git$//')
    COMPREPLY=($(compgen -W "$repos" -- "$cur"))
}

if [ -n "$BASH_VERSION" ]; then
    complete -F _wtr_completions wtr
    complete -F _wtr_completions wtd
    complete -F _wtr_completions wtm
    complete -F _wt_remove_completions wt-remove
    complete -F _wt_remove_completions wtrm
    complete -F _wt_remove_completions wt-hotfix-done
    complete -F _wtn_completions wtn
    complete -F _wtn_completions wtg
    complete -F _wt_status_completions wt-status
fi

# ============================================================
# Prompt Enhancement (Optional)
# ============================================================

# Uncomment to show worktree info in prompt
# wt_prompt_info() {
#     local wt_name=$(basename "$(pwd)")
#     local repo_name=$(basename "$(git rev-parse --git-common-dir 2>/dev/null)" .git)
#     if [ -n "$repo_name" ]; then
#         echo "[${repo_name}:${wt_name}]"
#     fi
# }

echo "✅ Worktree functions loaded. Type 'wt-status' to see all repos."
