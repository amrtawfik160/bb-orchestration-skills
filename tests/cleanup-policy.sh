#!/usr/bin/env bash

set -euo pipefail

# Regression: the cleanup skill keeps deletions recoverable, keeps read-only work
# parallel and mutating work serial, and proves its navigation layer cold.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
skill="$repo_root/skills/codebase-docs-cleanup/SKILL.md"
inventory="$repo_root/skills/codebase-docs-cleanup/references/inventory.md"
pruning="$repo_root/skills/codebase-docs-cleanup/references/pruning.md"
ledger="$repo_root/skills/codebase-docs-cleanup/references/ledger.md"
failed=0

require_pattern() {
  local file=$1
  local pattern=$2

  if ! grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: missing cleanup contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

reject_pattern() {
  local file=$1
  local pattern=$2
  local why=$3

  if grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: /%s/ %s\n' "${file#"$repo_root"/}" "$pattern" "$why"
    failed=1
  fi
}

# Deletions stay recoverable: a pinned worktree, never the source checkout.
require_pattern "$skill" 'one managed BB worktree at a pinned base'
require_pattern "$skill" 'source checkout is never'
require_pattern "$skill" 'discarding the branch reverts'
require_pattern "$skill" 'Pin `cleanup-base`'
require_pattern "$skill" 'Do not reset, force-clean, push, or open a pull request'

# A fresh worktree carries tracked files only, so untracked docs are invisible.
require_pattern "$skill" 'checks out tracked files only'
require_pattern "$skill" 'git ls-files --others --exclude-standard'
require_pattern "$skill" 'never deletes a file it cannot see'
require_pattern "$ledger" 'untracked_out_of_scope'

# Read-only work fans out; mutating work stays serial and verified.
require_pattern "$skill" 'read-only and run in parallel'
require_pattern "$skill" 'Every mutating batch is one'
require_pattern "$skill" 'serial worker, verified before the next'
require_pattern "$skill" 'one read-only worker per'
require_pattern "$skill" 'left `HEAD` and the tree unchanged'

# Baseline validation is captured before any edit and gates every batch.
require_pattern "$skill" 'Run it once at'
require_pattern "$skill" 'never evidence against a later batch'
require_pattern "$skill" 'A new failure against the baseline reverts that batch'
require_pattern "$ledger" '"baseline"'
require_pattern "$ledger" 'known_failures'

# Audit stops at the plan, and no report is written into the repository.
require_pattern "$skill" 'In audit mode, stop here'
require_pattern "$skill" 'BB_THREAD_STORAGE/codebase-docs-cleanup'
require_pattern "$skill" 'Never'
require_pattern "$skill" 'create a permanent cleanup report inside the repository'

# The navigation layer is proved by threads that never saw the cleanup.
require_pattern "$skill" 'cold-start workers'
require_pattern "$skill" 'no memory of this cleanup'
require_pattern "$skill" 'You have not seen this repository before'
require_pattern "$skill" 'is a failing pointer'
require_pattern "$ledger" 'navigation_checks'

# The final diff is read from BB, deletions included.
require_pattern "$skill" 'bb environment diff-files'
require_pattern "$skill" 'bb environment diff-patch'
require_pattern "$skill" 'deletions included'

# Judgement rules that keep the cleanup honest.
require_pattern "$skill" 'No deletion quota, target file count, or line limit'
require_pattern "$skill" 'never invent decision history'
require_pattern "$skill" 'is a finding, not a'
require_pattern "$skill" 'not permission to delete'

# Every classification class and prose test survives in the references.
for class in Mirror Drift Rationale Domain Navigation 'Operational' Unknown; do
  require_pattern "$inventory" "\*\*$class"
done
for test_name in 'Single source' 'No-op' 'Relevance' 'Hierarchy' 'Completion'; do
  require_pattern "$pruning" "\*\*$test_name:\*\*"
done
require_pattern "$pruning" 'Preserve effective instruction scope'
require_pattern "$pruning" 'Preserve public APIs'
require_pattern "$inventory" 'an unreferenced file is not automatically useless'

# The skill reuses the shared worker protocol instead of restating it.
require_pattern "$skill" '\.\./review-fix-loop/references/bb-workers.md'
require_pattern "$skill" '\.\./review-fix-loop/references/worker-footer.md'
reject_pattern "$skill" '^## Wait' 'restates the shared wait protocol'
reject_pattern "$skill" 'bb thread wait' 'restates the shared wait protocol'

if (( failed )); then
  exit 1
fi

echo 'PASS cleanup keeps deletions recoverable, fans out only read-only work, and proves navigation cold'
