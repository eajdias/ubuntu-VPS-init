---
name: safe-git-automation
description: Procedures for safely updating git repositories in automation scripts (e.g., VPS install scripts). Prevents data loss from accidental merges, rebases, or hard resets when local changes are present.
---

# Safe Git Automation

Automated scripts that perform `git pull` or `git reset` can cause data loss if the user has local commits or uncommitted changes.

## Procedures

### 1. Safe Update Strategy
Before performing an update, check for the state of the local repository.

```bash
# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo "⚠️ Warning: Local uncommitted changes detected. Skipping automatic update."
    # Optional: exit or ask for user confirmation if in TTY
    exit 1
fi

# Check for local commits not on remote (divergence)
git fetch origin
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u})
BASE=$(git merge-base HEAD @{u})

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "✅ Already up to date."
elif [ "$LOCAL" = "$BASE" ]; then
    echo "🔄 Fast-forwarding..."
    git pull --ff-only
elif [ "$REMOTE" = "$BASE" ]; then
    echo "⚠️ Warning: Local commits detected. Manual sync required."
    exit 1
else
    echo "⚠️ Warning: Diverged branches. Manual sync required."
    exit 1
fi
```

### 2. Forced Update (Production/VPS Only)
If the environment is a pure production VPS where local changes should NEVER happen or are irrelevant:

```bash
# WARNING: This will discard ALL local changes and commits
git fetch origin
git reset --hard origin/main
```

### 3. Preserve Local Changes (Stash Pattern)
When you want to pull updates but keep local modifications (like `.env` files), use `git stash` to wrap the update.

```bash
# Temporarily stash local changes (ignore error if none)
git stash &> /dev/null || true

git pull

# Restore stashed changes (ignore error if none)
git stash pop &> /dev/null || true
```

## Verification
- Verify the working directory is clean before the script runs.
- Test with local commits to ensure the script warns rather than rebases.

## Pitfalls
- **Detached HEAD**: Scripts might fail if the repo is in a detached HEAD state.
- **Submodules**: `git pull` does not update submodules by default; use `git submodule update --init --recursive`.
- **Config Interference**: User-level `pull.rebase=true` can change `git pull` behavior unexpectedly. Always use `--ff-only` or specific flags in scripts.
