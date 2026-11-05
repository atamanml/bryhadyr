#!/usr/bin/env bash
# Read-only list of a repository's git worktrees: dirty, merged into the base branch, or used by a running process.
# Only a worktree that is clean, merged and unused is safe to remove, and even then with plain `git worktree remove`, never --force.
# A branch squash-merged through a pull request is not an ancestor of the base; it counts as merged when the PR's head is the branch tip.
# Usage: worktree_audit.sh [repo] [base]   (default: current directory, origin/main)
set -u
repo="${1:-.}"
base="${2:-origin/main}"
cd "$repo" || exit 1
root="$(git rev-parse --show-toplevel)"
slug="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@[^:]+:|https://[^/]+/)##; s#\.git$##')"
git fetch -q --prune origin 2>/dev/null
printf 'worktree | branch | dirty files | merged | processes inside\n'
git worktree list --porcelain | awk '/^worktree /{sub(/^worktree /,""); w=$0} /^branch /{sub("refs/heads/","",$2); print w "\t" $2} /^detached/{print w "\t(detached)"}' |
while IFS="$(printf '\t')" read -r w b; do
  [ "$w" = "$root" ] && continue
  dirty="$(git -C "$w" status --porcelain 2>/dev/null | wc -l)"
  merged=no
  if [ "$b" != "(detached)" ]; then
    if git merge-base --is-ancestor "$b" "$base" 2>/dev/null; then
      merged=yes
    elif [ -n "$slug" ] && command -v gh >/dev/null 2>&1; then
      head="$(gh pr list --repo "$slug" --head "$b" --state merged --json headRefOid --jq '.[0].headRefOid // empty' 2>/dev/null)"
      [ -n "$head" ] && [ "$head" = "$(git rev-parse "$b")" ] && merged=pr
    fi
  fi
  users=0
  command -v lsof >/dev/null 2>&1 && users="$(lsof +D "$w" 2>/dev/null | awk 'NR>1{print $2}' | sort -u | wc -l)"
  printf '%s | %s | %s | %s | %s\n' "$w" "$b" "$dirty" "$merged" "$users"
done
