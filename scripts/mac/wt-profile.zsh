#!/bin/zsh
# wt-profile.zsh - Worktree management for macOS/zsh
# Add to ~/.zshrc:  source ~/Developer/worktree-management/mac/wt-profile.zsh

export WORKTREE_ROOT="$HOME/Developer/worktrees"
export WORKTREE_SCRIPTS="$(cd "$(dirname "${(%):-%x}")" && pwd)"
export WORKBENCH_ROOT="${WORKBENCH_ROOT:-$(cd "$WORKTREE_SCRIPTS/../.." && pwd)}"

_wt_python() {
    if command -v python3 >/dev/null 2>&1; then
        echo python3
    else
        echo python
    fi
}

_wt_run_python() {
    local script="$1"
    shift
    "$(_wt_python)" "$WORKBENCH_ROOT/scripts/worktrees/$script" "$@"
}

# ============================================================
# Core Commands
# ============================================================

wt-migrate()  { _wt_run_python wt_migrate.py "$@"; }
wt-status()   { _wt_run_python wt_status.py "$@"; }
wt-cleanup()  { _wt_run_python wt_cleanup.py "$@"; }

wt-feature() {
    local output rc worktree_path
    output="$(_wt_run_python wt_feature.py --workdir "$PWD" "$@" 2>&1)"
    rc=$?
    print -r -- "$output"
    if [[ $rc -eq 0 ]]; then
        worktree_path=$(print -r -- "$output" | awk -F= '/^WORKTREE_PATH=/{print $2; exit}')
        [[ -n "$worktree_path" && -d "$worktree_path" ]] && cd "$worktree_path"
    fi
    return $rc
}

wt-review() {
    local output rc worktree_path
    output="$(_wt_run_python wt_review.py --workdir "$PWD" "$@" 2>&1)"
    rc=$?
    print -r -- "$output"
    if [[ $rc -eq 0 ]]; then
        worktree_path=$(print -r -- "$output" | awk -F= '/^WORKTREE_PATH=/{print $2; exit}')
        [[ -n "$worktree_path" && -d "$worktree_path" ]] && cd "$worktree_path"
    fi
    return $rc
}

wt-review-done() { _wt_run_python wt_review_done.py --workdir "$PWD" "$@"; }

wt-hotfix() {
    local output rc worktree_path
    output="$(_wt_run_python wt_hotfix.py --workdir "$PWD" "$@" 2>&1)"
    rc=$?
    print -r -- "$output"
    if [[ $rc -eq 0 ]]; then
        worktree_path=$(print -r -- "$output" | awk -F= '/^WORKTREE_PATH=/{print $2; exit}')
        [[ -n "$worktree_path" && -d "$worktree_path" ]] && cd "$worktree_path"
    fi
    return $rc
}

wt-hotfix-done() { _wt_run_python wt_hotfix_done.py --workdir "$PWD" "$@"; }

# wt-test — source the repo's bare-root .env (durable live-test creds) into the
# SAME shell, then run the given command. Fixes the "live gates silently skip
# because conftest doesn't load .env" trap. Usage:
#   wt-test uv run pytest -m integration_dev path/to/test.py
wt-test() {
    local common envf
    common="$(git rev-parse --git-common-dir 2>/dev/null)" || { echo "wt-test: not in a git repo" >&2; return 1; }
    [[ "$common" = /* ]] || common="$PWD/$common"
    envf="$common/.env"
    if [[ -f "$envf" ]]; then
        set -a; source "$envf"; set +a
        echo "wt-test: sourced $envf" >&2
    else
        echo "wt-test: no .env at $envf — running without it (live gates may skip)" >&2
    fi
    [[ $# -gt 0 ]] || { echo "wt-test: pass a command, e.g. wt-test uv run pytest ..." >&2; return 2; }
    "$@"
}

wt-remove() {
    local repo_root rc
    repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null || echo "$WORKTREE_ROOT")
    _wt_run_python wt_remove.py --workdir "$PWD" "$@"
    rc=$?
    # cd to repo root if current dir was deleted
    [[ $rc -eq 0 && ! -d "$PWD" ]] && cd "$repo_root"
    return $rc
}

wt-sync() { _wt_run_python wt_sync.py --workdir "$PWD" "$@"; }

wt-release() { _wt_run_python wt_release.py --workdir "$PWD" "$@"; }

wt-hotfix-pr() {
    local output rc worktree_path
    output="$(_wt_run_python wt_hotfix_pr.py --workdir "$PWD" "$@" 2>&1)"
    rc=$?
    print -r -- "$output"
    if [[ $rc -eq 0 ]]; then
        worktree_path=$(print -r -- "$output" | awk -F= '/^WORKTREE_PATH=/{print $2; exit}')
        [[ -n "$worktree_path" && -d "$worktree_path" ]] && cd "$worktree_path"
    fi
    return $rc
}

wt-sync-permissions() { _wt_run_python wt_sync_permissions.py --workdir "$PWD" "$@"; }

# ============================================================
# Navigation
# ============================================================

# Jump to worktree root
wtgo() { cd "$WORKTREE_ROOT"; }

# Jump to / list repos
wtr() {
    if [[ -z "$1" ]]; then
        ls -1 "$WORKTREE_ROOT" 2>/dev/null | grep '\.git$' | sed 's/\.git$//'
        return
    fi
    cd "$WORKTREE_ROOT/${1}.git"
}

# Jump to develop worktree
wtd() {
    if [[ -n "$1" ]]; then
        cd "$WORKTREE_ROOT/${1}.git/develop" 2>/dev/null || echo "No develop worktree for $1"
        return
    fi
    local root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
    [[ -n "$root" ]] && cd "$root/develop" 2>/dev/null || echo "No develop worktree"
}

# Jump to main worktree
wtm() {
    if [[ -n "$1" ]]; then
        cd "$WORKTREE_ROOT/${1}.git/main" 2>/dev/null || echo "No main worktree for $1"
        return
    fi
    local root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
    [[ -n "$root" ]] && cd "$root/main" 2>/dev/null || echo "No main worktree"
}

# List worktrees in current repo
wtl() { git worktree list; }

# ============================================================
# Interactive Navigation (fzf-powered)
# ============================================================

wtn() {
    local launch_claude=false

    # Handle flags
    while [[ $# -gt 0 ]]; do
        case $1 in
            --code|-c) launch_claude=true; shift ;;
            -)
                # Go to last worktree
                if [[ -f ~/.wt_last ]]; then
                    local last_dir=$(cat ~/.wt_last)
                    if [[ -d "$last_dir" ]]; then
                        echo "$(pwd)" > ~/.wt_last
                        cd "$last_dir"
                        echo "$(pwd)"
                        [[ "$launch_claude" == true ]] && claude
                        return 0
                    else
                        echo "Last worktree no longer exists: $last_dir"
                        return 1
                    fi
                else
                    echo "No previous worktree"
                    return 1
                fi
                ;;
            *) shift ;;
        esac
    done

    local repo_path=""
    local git_dir=$(git rev-parse --git-common-dir 2>/dev/null)

    if [[ -n "$git_dir" && "$git_dir" != "." ]]; then
        repo_path=$(cd "$git_dir" && pwd)
    elif [[ -n "$git_dir" && "$git_dir" == "." ]]; then
        repo_path=$(pwd)
    fi

    # Select repo if not in one
    if [[ -z "$repo_path" ]]; then
        local repos=$(ls -1 "$WORKTREE_ROOT" 2>/dev/null | grep '\.git$' | sed 's/\.git$//')
        [[ -z "$repos" ]] && { echo "No repos in $WORKTREE_ROOT"; return 1; }

        local selected=$(echo "$repos" | fzf --prompt="repo: " --height=~40% --reverse --border)
        [[ -z "$selected" ]] && return 0
        repo_path="$WORKTREE_ROOT/${selected}.git"
    fi

    local repo_name=$(basename "$repo_path" .git)

    # Build worktree list
    local worktrees=""
    [[ -d "$repo_path/main" ]] && worktrees+="main\n"
    [[ -d "$repo_path/develop" ]] && worktrees+="develop\n"
    for kind in _feature _hotfix _review; do
        [[ -d "$repo_path/$kind" ]] || continue
        local label="${kind#_}"
        for d in "$repo_path/$kind"/*(N/); do
            worktrees+="$(basename "$d") [$label]\n"
        done
    done

    [[ -z "$worktrees" ]] && { echo "No worktrees in $repo_name"; return 1; }

    local selected=$(echo -e "$worktrees" | sed '/^$/d' | fzf --prompt="$repo_name> " --height=~40% --reverse --border)
    [[ -z "$selected" ]] && return 0

    # Extract name (strip label)
    local name="${selected%% \[*\]}"

    # Find and cd to path
    for candidate in "$repo_path/$name" "$repo_path/_feature/$name" "$repo_path/_hotfix/$name" "$repo_path/_review/$name"; do
        if [[ -d "$candidate" ]]; then
            # Save current dir as last worktree
            echo "$(pwd)" > ~/.wt_last
            cd "$candidate"
            echo "$(pwd)"
            [[ "$launch_claude" == true ]] && claude
            return 0
        fi
    done

    echo "Not found: $name"
    return 1
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
# Zsh Completions
# ============================================================

_wt_repos() {
    local repos=(${(f)"$(ls -1 "$WORKTREE_ROOT" 2>/dev/null | grep '\.git$' | sed 's/\.git$//')"})
    compadd -a repos
}

if (( $+functions[compdef] )); then
    compdef _wt_repos wtr wtd wtm wt-status
fi

# Worktree name completion (for wt-remove, wt-hotfix-done)
_wt_remove() {
    local repo_root=$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir 2>/dev/null)
    [[ -z "$repo_root" ]] && return

    # Complete flags
    if [[ "$PREFIX" == -* ]]; then
        local -a flags
        flags=(
            '-f:Force remove'
            '--force:Force remove'
            '-d:Delete the associated branch'
            '--delete-branch:Delete the associated branch'
            '-k:Keep the associated branch'
            '--keep-branch:Keep the associated branch'
            '-y:Skip all confirmation prompts'
            '--yes:Skip all confirmation prompts'
            '--stale:Remove worktrees with no commits in N days'
        )
        _describe 'flag' flags
        return
    fi

    # Complete worktree names
    local names=()
    for kind in _feature _hotfix _review; do
        [[ -d "$repo_root/$kind" ]] || continue
        for d in "$repo_root/$kind"/*/; do
            [[ -d "$d" ]] && names+=($(basename "$d"))
        done
    done
    compadd -a names
}

if (( $+functions[compdef] )); then
    compdef _wt_remove wt-remove wtrm wt-hotfix-done
fi

# wtn completion (flags only since it's interactive)
_wtn() {
    if [[ "$PREFIX" == -* ]]; then
        local -a flags
        flags=(
            '-c:Launch Claude Code after navigating'
            '--code:Launch Claude Code after navigating'
            '-:Go to last worktree'
        )
        _describe 'flag' flags
        return
    fi
}

if (( $+functions[compdef] )); then
    compdef _wtn wtn wtg wtc wtcd
fi

# Silenced to avoid p10k instant prompt warning
# To check: run `wt-status` or `wtr` to list repos
