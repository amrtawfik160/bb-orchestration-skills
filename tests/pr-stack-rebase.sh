#!/usr/bin/env bash

set -euo pipefail

# Behavior test: the documented parent-merge procedure in pr-stack.md keeps a
# child PR at one ticket after both a merge commit and a squash merge.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stack="$repo_root/skills/orchestrate-implementation/references/pr-stack.md"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failed=0

fail() {
  printf 'FAIL %s\n' "$1"
  failed=1
}

patch_id() {
  git diff "$1" "$2" | git patch-id --stable | cut -d' ' -f1
}

setup_repo() {
  local dir=$1
  git init -q -b main "$dir"
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  git -C "$dir" commit -q --allow-empty -m 'root'
  echo base >"$dir/base.txt"
  git -C "$dir" add . && git -C "$dir" commit -q -m 'base'

  git -C "$dir" checkout -q -b ticket-a
  echo a >"$dir/a.txt"
  git -C "$dir" add . && git -C "$dir" commit -q -m 'ticket A'

  git -C "$dir" checkout -q -b ticket-b
  echo b >"$dir/b.txt"
  git -C "$dir" add . && git -C "$dir" commit -q -m 'ticket B'
  git -C "$dir" checkout -q main
}

# Case 1: merge commit keeps the parent's commits -> direct retarget.
repo="$tmp/merge"
setup_repo "$repo"
cd "$repo"
parent_head=$(git rev-parse ticket-a)
expected=$(patch_id ticket-a ticket-b)
git merge -q --no-ff ticket-a -m 'merge A'
if git merge-base --is-ancestor "$parent_head" main; then
  [[ "$(patch_id main ticket-b)" == "$expected" ]] || fail 'merge commit: child diff changed after direct retarget'
  [[ "$(git diff --name-only main...ticket-b)" == 'b.txt' ]] || fail 'merge commit: child diff is not one ticket'
else
  fail 'merge commit: procedure should detect direct retarget'
fi

# Case 2: squash merge rewrites the parent -> rebase --onto is required.
repo="$tmp/squash"
setup_repo "$repo"
cd "$repo"
parent_head=$(git rev-parse ticket-a)
expected=$(patch_id ticket-a ticket-b)
git merge -q --squash ticket-a && git commit -q -m 'squash A'
if git merge-base --is-ancestor "$parent_head" main; then
  fail 'squash merge: procedure should detect that a rebase is required'
fi
[[ "$(git diff --name-only main...ticket-b)" == $'a.txt\nb.txt' ]] \
  || fail 'squash merge: precondition failed, child should show both tickets before rebase'

# The documented command, with origin/<target> replaced by the local main.
git rebase -q --onto main "$parent_head" ticket-b
[[ "$(patch_id main ticket-b)" == "$expected" ]] || fail 'squash merge: child diff changed after rebase'
[[ "$(git diff --name-only main...ticket-b)" == 'b.txt' ]] || fail 'squash merge: child diff is not one ticket after rebase'

# The documented command text must match what this test ran.
grep -q 'git rebase --onto origin/<target> <parent-accepted-head> <child-branch>' "$stack" \
  || fail 'pr-stack.md: rebase command text drifted from the tested procedure'

if (( failed )); then
  exit 1
fi

echo 'PASS parent merges keep each child PR at one ticket'
