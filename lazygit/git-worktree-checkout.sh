#!/bin/bash
set -e

CREATE=false
if [ "$1" = "--create" ]; then
  CREATE=true
  shift
fi

BRANCH="$1"
if [ -z "$BRANCH" ]; then
  echo "Usage: $0 [--create] <branch-name>"
  exit 1
fi

TMP_FILE="/tmp/lazygit-worktree-path"

# Get the main worktree root (first entry is always the main worktree)
MAIN_WORKTREE=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')

# Determine default branch
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
if [ -z "$DEFAULT_BRANCH" ]; then
  if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
    DEFAULT_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
    DEFAULT_BRANCH="master"
  fi
fi

# For the default branch, ensure main worktree is on it and switch there
if [ "$BRANCH" = "$DEFAULT_BRANCH" ]; then
  CURRENT=$(git -C "$MAIN_WORKTREE" rev-parse --abbrev-ref HEAD)
  if [ "$CURRENT" != "$DEFAULT_BRANCH" ]; then
    git -C "$MAIN_WORKTREE" checkout "$DEFAULT_BRANCH"
  fi
  echo "$MAIN_WORKTREE" > "$TMP_FILE"
  echo "→ Main branch '$BRANCH' at: $MAIN_WORKTREE"
  exit 0
fi

# Check if a worktree already exists for this branch
EXISTING=$(git worktree list --porcelain | awk -v branch="refs/heads/$BRANCH" '
  /^worktree / { wt = substr($0, 10) }
  /^branch / { if ($2 == branch) print wt }
')

if [ -n "$EXISTING" ]; then
  echo "$EXISTING" > "$TMP_FILE"
  echo "→ Worktree for '$BRANCH' exists at: $EXISTING"
else
  # If the branch is currently checked out in the main worktree, switch main to default first
  CURRENT=$(git -C "$MAIN_WORKTREE" rev-parse --abbrev-ref HEAD)
  if [ "$CURRENT" = "$BRANCH" ]; then
    echo "Branch '$BRANCH' is checked out in main worktree, switching main to '$DEFAULT_BRANCH'..."
    git -C "$MAIN_WORKTREE" checkout "$DEFAULT_BRANCH"
  fi

  SAFE_BRANCH=$(echo "$BRANCH" | tr '/' '-')
  WORKTREE_DIR="$MAIN_WORKTREE/.worktrees/$SAFE_BRANCH"

  # Ensure .worktrees is in local git exclude (not committed to repo)
  GIT_COMMON_DIR=$(git rev-parse --git-common-dir)
  EXCLUDE_FILE="$GIT_COMMON_DIR/info/exclude"
  mkdir -p "$(dirname "$EXCLUDE_FILE")"
  grep -qxF '.worktrees' "$EXCLUDE_FILE" 2>/dev/null || echo '.worktrees' >> "$EXCLUDE_FILE"

  mkdir -p "$(dirname "$WORKTREE_DIR")"
  if [ "$CREATE" = true ]; then
    git worktree add -b "$BRANCH" "$WORKTREE_DIR"
  else
    git worktree add "$WORKTREE_DIR" "$BRANCH"
  fi
  echo "$WORKTREE_DIR" > "$TMP_FILE"
  echo "→ Created worktree at: $WORKTREE_DIR"
fi
