#!/bin/bash
# wt-entire-fix.sh - Patch Entire CLI hooks for Windows bare repo compatibility
#
# Entire's go-git fails to rename over read-only loose objects on Windows.
# This patches the post-commit hook to make objects writable before Entire runs.
# See: https://github.com/entireio/cli/issues/431
#
# Usage:
#   wt-entire-fix              # Fix current repo
#   wt-entire-fix --all        # Fix all managed repos

set -e

WORKTREE_ROOT="${WORKTREE_ROOT:-C:/worktrees}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step()    { echo -e "${BLUE}▶${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1"; }

HOOK_CONTENT='#!/bin/sh
# Entire CLI hooks
# Post-commit hook: condense session data if commit has Entire-Checkpoint trailer

# Workaround: Entire'\''s go-git fails to rename over read-only loose objects on Windows.
# Make all loose objects writable before Entire runs.
# See: https://github.com/entireio/cli/issues/431
git_dir=$(git rev-parse --git-common-dir 2>/dev/null)
if [ -n "$git_dir" ] && [ -d "$git_dir/objects" ]; then
    find "$git_dir/objects" -maxdepth 2 -type f ! -path "*/pack/*.pack" ! -path "*/pack/*.idx" ! -path "*/pack/*.rev" -exec chmod u+w {} + 2>/dev/null
fi

entire hooks git post-commit 2>/dev/null || true
'

patch_repo() {
    local bare_repo=$1
    local repo_name=$(basename "$bare_repo")
    # For regular repos, show parent dir name instead of ".git"
    if [ "$repo_name" = ".git" ]; then
        repo_name=$(basename "$(dirname "$bare_repo")")
    fi
    local hook_file="$bare_repo/hooks/post-commit"

    if [ ! -f "$hook_file" ]; then
        print_warning "$repo_name — no post-commit hook (run 'entire enable' first)"
        return 1
    fi

    if ! grep -q "entire hooks git post-commit" "$hook_file"; then
        print_warning "$repo_name — post-commit hook is not from Entire (skipping)"
        return 1
    fi

    if grep -q "git_dir=.*git-common-dir" "$hook_file"; then
        print_success "$repo_name — already patched"
        return 0
    fi

    echo "$HOOK_CONTENT" > "$hook_file"
    print_success "$repo_name — patched"
    return 0
}

# Find the git dir (hooks location) from current directory
# Works for both bare repos with worktrees and regular repos
find_git_dir() {
    local git_common_dir
    git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
    if [ -z "$git_common_dir" ]; then
        return 1
    fi
    # Resolve to absolute path
    (cd "$git_common_dir" && pwd)
}

main() {
    if [ "${1:-}" = "--all" ]; then
        echo ""
        echo "Patching Entire hooks in all managed repos..."
        echo ""

        local patched=0
        local skipped=0

        # Scan bare repos (*.git directories with hooks/)
        for repo in "$WORKTREE_ROOT"/*.git; do
            if [ -d "$repo/hooks" ]; then
                if patch_repo "$repo"; then
                    ((patched++)) || true
                else
                    ((skipped++)) || true
                fi
            fi
        done

        # Scan regular repos (directories with .git/hooks/)
        for repo_dir in "$WORKTREE_ROOT"/*/; do
            # Skip bare repos (already handled above) and non-git dirs
            [[ "$repo_dir" == *.git/ ]] && continue
            if [ -d "$repo_dir/.git/hooks" ]; then
                if patch_repo "$repo_dir/.git"; then
                    ((patched++)) || true
                else
                    ((skipped++)) || true
                fi
            fi
        done

        echo ""
        echo "Done. Patched: $patched, Skipped: $skipped"
    else
        # Fix current repo
        local git_dir
        git_dir=$(find_git_dir)
        if [ $? -ne 0 ] || [ -z "$git_dir" ]; then
            print_error "Not inside a git repository. Run from a repo or use --all."
            exit 1
        fi

        echo ""
        patch_repo "$git_dir"
        echo ""
    fi
}

main "$@"
