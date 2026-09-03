#!/usr/bin/env bash

set -euo pipefail

# Regression: landing must be ordered, gated, one-way-safe, and must clean up
# only after a confirmed merge.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
land="$repo_root/skills/land-stack/SKILL.md"
orchestrator="$repo_root/skills/orchestrate-implementation/SKILL.md"
stack="$repo_root/skills/orchestrate-implementation/references/pr-stack.md"
ledger="$repo_root/skills/orchestrate-implementation/references/ledger.md"
readme="$repo_root/README.md"
failed=0

require_pattern() {
  local file=$1
  local pattern=$2

  if ! grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: missing landing contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

reject_pattern() {
  local file=$1
  local pattern=$2

  if grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: unsafe landing contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

# Order and gating.
require_pattern "$land" 'Land oldest first'
require_pattern "$land" 'oldest unmerged ticket'
require_pattern "$land" 'gh pr checks "\$URL" --watch --fail-fast'
require_pattern "$land" 'mergeable: MERGEABLE'
require_pattern "$land" 'headRefOid` equal to'
require_pattern "$land" '--match-head-commit'
require_pattern "$land" 'reviewDecision: APPROVED'
require_pattern "$land" '--require-approvals'
require_pattern "$land" 'reviewThreads'

# Unresolved comments re-enter the review gate rather than blocking silently.
require_pattern "$land" '/review-fix-loop <target> <ticket> --from-pr <url>'

# One-way safety: stop at the first failure, keep merged work, resume forward.
require_pattern "$land" 'Stop at the first PR that cannot merge'
require_pattern "$land" 'Merged tickets stay merged'
require_pattern "$land" 'Nothing merged is undone'
require_pattern "$land" 'starts at the first unmerged ticket'

# Cleanup is gated on a confirmed merge.
require_pattern "$land" 'state` must be `MERGED`'
require_pattern "$land" 'only after its merge is confirmed on the remote'
require_pattern "$land" 'bb environment archive-threads'
require_pattern "$land" 'removes the worktree and its local branch'
require_pattern "$land" 'Confirm the worktree path is'
require_pattern "$land" '--keep-environments'

# Issue closing is verified, not assumed.
require_pattern "$land" 'gh issue view <n> --json state'
require_pattern "$land" 'gh issue close <n> --reason completed'

# Merge method selection keeps children retargetable.
require_pattern "$land" 'allow_merge_commit'
require_pattern "$land" 'A merge commit keeps children retargetable'
require_pattern "$land" 'squash and rebase need the'

# Landing never runs before the graph is accepted.
require_pattern "$land" 'state: finished'
reject_pattern "$land" 'merge without checks|skip the gate'

# --land needs the orchestrator to reach this skill, so it must stay
# model-invocable, like review-fix-loop.
reject_pattern "$land" '^disable-model-invocation: true$'

# GitHub calls go through gh-axi when it is installed, with syntax read from
# the CLI rather than pinned in these docs.
protocol="$repo_root/skills/review-fix-loop/references/bb-workers.md"
require_pattern "$protocol" '## GitHub'
require_pattern "$protocol" 'Prefer the `gh-axi` skill over raw `gh`'
require_pattern "$protocol" 'npx -y gh-axi <command> --help'
require_pattern "$protocol" 'never from memory'
require_pattern "$protocol" 'not which binary runs it'
require_pattern "$protocol" 'fall back to `gh` when it is not'
require_pattern "$protocol" 'gh-axi stack` needs the `github/gh-stack` extension'
require_pattern "$land" 'prefer the `gh-axi` skill over raw `gh`'
require_pattern "$stack" 'Run them through'
require_pattern "$orchestrator" 'gh-axi'
require_pattern "$readme" 'gh-axi'

# Orchestrator hand-off.
require_pattern "$orchestrator" '--land'
require_pattern "$orchestrator" 'belong to `land-stack`'
require_pattern "$orchestrator" 'LANDABLE: yes'
require_pattern "$orchestrator" 'LANDABLE: no'
require_pattern "$orchestrator" '`status` prints the ledger and takes no action'
require_pattern "$stack" 'land-stack` merges the whole stack oldest first'
require_pattern "$ledger" '"landing"'
require_pattern "$ledger" 'environment_state'
require_pattern "$readme" 'land-stack'

if (( failed )); then
  exit 1
fi

echo 'PASS landing merges in order, gates each PR, and cleans up after confirmation'
