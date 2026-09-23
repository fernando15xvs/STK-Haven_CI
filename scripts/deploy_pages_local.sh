#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -d apps/app_web/build/web ]]; then
  echo "ERROR: apps/app_web/build/web does not exist. Run scripts/validate_local.sh or build web first." >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree has uncommitted changes. Commit or stash them first." >&2
  exit 1
fi

PAGES_DIR="$(mktemp -d)/stk-haven-pages"
cleanup() {
  git worktree remove --force "$PAGES_DIR" >/dev/null 2>&1 || true
  rm -rf "$(dirname "$PAGES_DIR")"
}
trap cleanup EXIT

if git show-ref --verify --quiet refs/remotes/origin/gh-pages; then
  git worktree add --detach "$PAGES_DIR" origin/gh-pages
  (
    cd "$PAGES_DIR"
    git checkout -B gh-pages
  )
elif git show-ref --verify --quiet refs/heads/gh-pages; then
  git worktree add "$PAGES_DIR" gh-pages
else
  git worktree add --detach "$PAGES_DIR" HEAD
  (
    cd "$PAGES_DIR"
    git checkout --orphan gh-pages
    git rm -rf . >/dev/null 2>&1 || true
  )
fi

find "$PAGES_DIR" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -R apps/app_web/build/web/. "$PAGES_DIR/"
touch "$PAGES_DIR/.nojekyll"

(
  cd "$PAGES_DIR"
  git add -A
  if git diff --cached --quiet; then
    echo "GitHub Pages is already up to date."
    exit 0
  fi
  git commit -m "deploy: GitHub Pages $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  git push origin gh-pages --force
)

echo "SUCCESS: validated web build published to gh-pages."
