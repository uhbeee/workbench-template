#!/bin/bash
# wt-init.sh - Initialize a repository for worktree workflow
# Usage: wt-init <repo_url> [repo_name]

set -e

WORKTREE_ROOT="${WORKTREE_ROOT:-C:/worktrees}"

repo_url=$1
repo_name=${2:-$(basename "$repo_url" .git)}

if [ -z "$repo_url" ]; then
    echo "Usage: wt-init <repo_url> [repo_name]"
    echo "Example: wt-init https://github.com/your-org/backend.git"
    exit 1
fi

# Patch Entire CLI's post-commit hook for Windows bare repo compatibility
# Entire's go-git fails to rename over read-only loose objects on Windows.
# See: https://github.com/entireio/cli/issues/431
patch_entire_hooks() {
    local bare_repo=$1
    local hook_file="$bare_repo/hooks/post-commit"

    if [ ! -f "$hook_file" ]; then
        return
    fi

    if grep -q "entire hooks git post-commit" "$hook_file" && ! grep -q "git_dir=.*git-common-dir" "$hook_file"; then
        echo "🔧 Patching Entire post-commit hook for Windows compatibility..."
        cat > "$hook_file" << 'HOOK'
#!/bin/sh
# Entire CLI hooks
# Post-commit hook: condense session data if commit has Entire-Checkpoint trailer

# Workaround: Entire's go-git fails to rename over read-only loose objects on Windows.
# Make all loose objects writable before Entire runs.
# See: https://github.com/entireio/cli/issues/431
git_dir=$(git rev-parse --git-common-dir 2>/dev/null)
if [ -n "$git_dir" ] && [ -d "$git_dir/objects" ]; then
    find "$git_dir/objects" -maxdepth 2 -type f ! -path "*/pack/*.pack" ! -path "*/pack/*.idx" ! -path "*/pack/*.rev" -exec chmod u+w {} + 2>/dev/null
fi

entire hooks git post-commit 2>/dev/null || true
HOOK
        echo "✅ Patched Entire post-commit hook"
    fi
}

echo "🔧 Initializing ${repo_name} for worktree workflow..."

cd "$WORKTREE_ROOT"

# Clone as bare repository
echo "📦 Cloning bare repository..."
git clone --bare "$repo_url" "${repo_name}.git"

cd "${repo_name}.git"

# Fix fetch refspec (critical for bare repos to track remotes properly)
echo "⚙️  Configuring remote tracking..."
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch origin

# Detect default branch
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
echo "📌 Default branch detected: ${default_branch}"

# Create main/master worktree (with local branch tracking remote)
echo "🌳 Creating main worktree..."
if git show-ref --verify --quiet "refs/remotes/origin/main"; then
    if git show-ref --verify --quiet "refs/heads/main"; then
        git worktree add main main
    else
        git worktree add --track -b main main origin/main
    fi
elif git show-ref --verify --quiet "refs/remotes/origin/master"; then
    if git show-ref --verify --quiet "refs/heads/main"; then
        git worktree add main main
    else
        git worktree add --track -b main main origin/master
    fi
fi

# Create develop worktree if it exists (with local branch tracking remote)
if git show-ref --verify --quiet "refs/remotes/origin/develop"; then
    echo "🌳 Creating develop worktree..."
    if git show-ref --verify --quiet "refs/heads/develop"; then
        git worktree add develop develop
    else
        git worktree add --track -b develop develop origin/develop
    fi
fi

# Create empty directories for feature and review worktrees
mkdir -p _feature _review _hotfix

# Patch Entire CLI hooks if present (Windows bare repo workaround)
patch_entire_hooks "${WORKTREE_ROOT}/${repo_name}.git"

echo ""
echo "✅ Successfully initialized ${repo_name}"
echo ""
echo "Structure:"
git worktree list
echo ""
echo "Next steps:"
echo "  cd ${WORKTREE_ROOT}/${repo_name}.git/develop"
echo "  wt-feature 'your-feature-name'"
