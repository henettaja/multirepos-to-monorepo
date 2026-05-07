#!/usr/bin/env bash
set -euo pipefail

# =========================
# CONFIGURATION
# =========================
TARGET_MONOREPO_LOCAL_NAME="syke-monorepo"
TARGET_MONOREPO_DEFAULT_BRANCH="main"
TARGET_MONOREPO_URL=""

WORKDIR="${PWD}/monorepo-work"
LOCAL_MONOREPO_TARGET_DIR="${WORKDIR}/${TARGET_MONOREPO_LOCAL_NAME}"

# Prefix tags with <subdir> in case imported repos include identical tags
PREFIX_TAGS=true

# "<git_url> <subdir>"
REPOS_TO_IMPORT=(
  "https://github.com/owner/repoA.git repoA"
  "https://github.com/owner/repoB.git repoB"
)

# =========================
# PREREQUISITES
# =========================
command -v git >/dev/null || { echo "❌ Git is required"; exit 1; }
command -v git-filter-repo >/dev/null || { echo "❌ git-filter-repo is required"; exit 1; }
mkdir -p "$WORKDIR"
git config --global --add safe.directory "$LOCAL_MONOREPO_TARGET_DIR" || true

# =========================
# TEMP WORKSPACE & CLEANUP
# =========================
TMP_ROOT="$(mktemp -d "${WORKDIR}/src.XXXXXX")"

cleanup() {
  echo "🧹 Cleaning up temporary directories..."
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

# =========================
# FUNCTIONS
# =========================
clone_monorepo() {
  if [ ! -d "$LOCAL_MONOREPO_TARGET_DIR/.git" ]; then
      git clone "$TARGET_MONOREPO_URL" "$LOCAL_MONOREPO_TARGET_DIR"
  fi
  cd "$LOCAL_MONOREPO_TARGET_DIR"
  git checkout -B "$TARGET_MONOREPO_DEFAULT_BRANCH"
  if ! git rev-parse --verify --quiet HEAD >/dev/null; then
    git commit --allow-empty -m "chore: initial empty commit"
    git push -u origin "$TARGET_MONOREPO_DEFAULT_BRANCH" || true
  fi
}

import_repo() {
  local git_url="$1"
  local subdir="$2"

  # Ensure subdir is safe
  if [[ "$subdir" == /* || "$subdir" == *".."* ]]; then
    echo "❌ Unsafe subdir '$subdir'; skipping."
    return
  fi

  local repo_dir="${TMP_ROOT}/${subdir//\//_}"
  rm -rf "$repo_dir"

  echo "==> Importing $git_url into $subdir/"
  git clone --quiet "$git_url" "$repo_dir"
  cd "$repo_dir"

  if ! git rev-parse --verify --quiet HEAD >/dev/null; then
    echo "⚠️  Skipping $git_url — repository is empty."
    cd "$LOCAL_MONOREPO_TARGET_DIR"
    rm -rf "$repo_dir"
    return
  fi

  # Default branch detection
  git remote set-head origin -a || true
  default_branch="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  if [ -z "$default_branch" ]; then
    default_branch="$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')"
  fi
  if [ -z "$default_branch" ]; then
    for cand in main master; do
      if git rev-parse --verify --quiet "origin/$cand" >/dev/null; then
        default_branch="$cand"
        break
      fi
    done
  fi
  if [ -z "$default_branch" ]; then
    default_branch="$(git for-each-ref --format='%(refname:short)' refs/remotes/origin | sed -n '1p' | sed 's#^origin/##')"
  fi
  [ -n "$default_branch" ] || { echo "❌ Could not detect default branch for $git_url"; rm -rf "$repo_dir"; return; }
  git checkout "$default_branch"

  # Prefix tags if needed
  if [ "$PREFIX_TAGS" = true ] && git tag | grep -q .; then
      git filter-repo --force --tag-rename "":"$subdir-"
  fi

  # Move repo content into subdir
  git filter-repo --force --to-subdirectory-filter "$subdir"

  cd "$LOCAL_MONOREPO_TARGET_DIR"
  local remote_name="import_$subdir"
  git remote remove "$remote_name" 2>/dev/null || true
  git remote add "$remote_name" "$repo_dir"
  git fetch "$remote_name" --tags
  git merge --allow-unrelated-histories --no-ff \
    -m "Import $subdir from $git_url ($default_branch)" \
    "$remote_name/$default_branch"
  git remote remove "$remote_name"

  # Immediate cleanup of this repo clone
  rm -rf "$repo_dir"
}

# =========================
# MAIN
# =========================
clone_monorepo

for entry in "${REPOS_TO_IMPORT[@]}"; do
  git_url=$(echo "$entry" | awk '{print $1}')
  subdir=$(echo "$entry" | awk '{print $2}')
  # Check that <git_url> and <subdir> are defined
  if [ -z "$git_url" ] || [ -z "$subdir" ]; then
    echo "⚠️  Skipping malformed REPOS_TO_IMPORT entry: $entry"
    continue
  fi
  import_repo "$git_url" "$subdir"
done

cd "$LOCAL_MONOREPO_TARGET_DIR"
if git tag | grep -q .; then
  git push -u origin "$TARGET_MONOREPO_DEFAULT_BRANCH" --tags
else
  git push -u origin "$TARGET_MONOREPO_DEFAULT_BRANCH"
fi

echo "✅ Done — all repos merged and pushed."
