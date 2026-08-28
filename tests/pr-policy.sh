#!/usr/bin/env bash

set -euo pipefail

# Regression: accepted tickets must not accumulate into one branch and PR.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
orchestrator="$repo_root/skills/orchestrate-implementation/SKILL.md"
loop="$repo_root/skills/review-fix-loop/SKILL.md"
readme="$repo_root/README.md"
failed=0

require_pattern() {
  local file=$1
  local pattern=$2

  if ! grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: missing PR contract /%s/\n' "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

reject_pattern() {
  local file=$1
  local pattern=$2

  if grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: cumulative PR contract remains /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

require_pattern "$orchestrator" 'One ticket owns one'
require_pattern "$orchestrator" 'spawns only'
require_pattern "$orchestrator" 'those phase workers'
require_pattern "$orchestrator" 'next gets a new'
require_pattern "$orchestrator" 'branch and environment'
require_pattern "$orchestrator" 'Opening a draft PR and pushing its ticket branch are part'
require_pattern "$orchestrator" 'open or `in review` until its PR merges'
require_pattern "$orchestrator" 'implicit cumulative implementation or final mega-PR'
require_pattern "$orchestrator" 'first ticket branches from the target branch'
require_pattern "$orchestrator" 'later ticket branches from the exact accepted head'
require_pattern "$orchestrator" 'PR targets that previous ticket branch'
require_pattern "$orchestrator" 'retarget its oldest open child'
require_pattern "$orchestrator" 'pr-base\.\.\.HEAD.*only this ticket'
require_pattern "$orchestrator" 'head equals the reviewed `HEAD`'
require_pattern "$orchestrator" 'Set the tracker to `in review`'
require_pattern "$orchestrator" 'push or PR creation fails, pause'
require_pattern "$orchestrator" 'create branch refs without rewriting'
require_pattern "$orchestrator" 'Every accepted'
require_pattern "$orchestrator" 'ticket must have one PR URL'

reject_pattern "$orchestrator" 'Reuse one cumulative environment'
reject_pattern "$orchestrator" 'mark it complete through the tracker'
reject_pattern "$orchestrator" 'Push, PR, merge, deploy, archive, and cleanup require separate requests'

require_pattern "$loop" 'caller owns branch push and PR creation'
require_pattern "$loop" 'LOOP_GATE'
reject_pattern "$loop" '^disable-model-invocation: true$'
require_pattern "$readme" 'One draft PR per accepted ticket'
require_pattern "$readme" 'there is no implicit final mega-PR'

if (( failed )); then
  exit 1
fi

echo 'PASS every accepted ticket has an isolated branch and PR boundary'
