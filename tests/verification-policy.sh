#!/usr/bin/env bash

set -euo pipefail

# Regression: worker claims are verified, validation is resolved once, ledgers
# have a schema, and every worker returns a parseable footer.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
orchestrator="$repo_root/skills/orchestrate-implementation/SKILL.md"
loop="$repo_root/skills/review-fix-loop/SKILL.md"
protocol="$repo_root/skills/bb-worker-protocol/references/bb-workers.md"
footer="$repo_root/skills/bb-worker-protocol/references/worker-footer.md"
loop_ledger="$repo_root/skills/review-fix-loop/references/ledger.md"
run_ledger="$repo_root/skills/bb-worker-protocol/references/run-ledger.md"
failed=0

require_pattern() {
  local file=$1
  local pattern=$2

  if ! grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: missing contract /%s/\n' "${file#"$repo_root"/}" "$pattern"
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

# Trust boundary: the orchestrator verifies in the worktree.
require_pattern "$protocol" 'The footer is a claim'
require_pattern "$protocol" 'git status --porcelain'
require_pattern "$protocol" 'git rev-parse HEAD'
require_pattern "$protocol" 'git merge-base --is-ancestor "\$BASE" HEAD'
require_pattern "$protocol" 'validation command from the ledger'
require_pattern "$orchestrator" 'Verify every'
require_pattern "$orchestrator" 'worker claim in the worktree'
require_pattern "$loop" 'Verify every claim in the worktree'

# Validation is resolved once, in one shared file, and run by the orchestrator.
validation="$repo_root/skills/bb-worker-protocol/references/validation.md"
require_pattern "$validation" 'ticket.s own validation line'
require_pattern "$validation" '`test`, `lint`, and `typecheck`'
require_pattern "$validation" 'never when the worker reported it|Run it yourself|run .validation. after every mutating worker'
require_pattern "$validation" 'Never record a validation you did not watch exit 0'
for skill in "$orchestrator" "$loop"; do
  require_pattern "$skill" 'Resolve `validation`'
  require_pattern "$skill" 'bb-worker-protocol/references/validation.md'
done
require_pattern "$orchestrator" 'run it yourself after every mutating worker'
require_pattern "$loop" 'run it yourself after every fix'

# The ladder is defined once. A skill that restates it is a copy that will drift.
for skill in "$orchestrator" "$loop" "$repo_root/skills/codebase-docs-cleanup/SKILL.md"; do
  reject_pattern "$skill" '`test`, `lint`, and `typecheck`' \
    'restates the resolution ladder that validation.md owns'
done

# Worker footer contract.
require_pattern "$footer" '^WORKER_RESULT:$'
require_pattern "$footer" 'status: DONE \| BLOCKED'
require_pattern "$footer" 'tree: clean \| dirty'
require_pattern "$footer" 'validation: PASS \| FAIL \| NOT_RUN'
require_pattern "$footer" 'verdict: CONFIRMED \| DISPUTED'
require_pattern "$footer" 'state: RESOLVED \| OPEN \| CONFIRMED_FIX_REGRESSION'
require_pattern "$footer" 'pr_url'
require_pattern "$protocol" 'Always attach `worker-footer.md`'
require_pattern "$protocol" 'A missing or malformed footer'

# Ledger schemas.
require_pattern "$loop_ledger" 'review-fix-loop/<review-base-7-char-sha>.json'
require_pattern "$run_ledger" 'orchestrate-implementation/run.json'
require_pattern "$loop" 'references/ledger.md'
require_pattern "$orchestrator" 'bb-worker-protocol/SKILL.md'
require_pattern "$orchestrator" '\| resume'
require_pattern "$orchestrator" '`resume`, or'

for ledger in "$loop_ledger" "$run_ledger"; do
  for key in '"schema": 1' '"state"' '"validation"' '"budget"' '"phases"' '"pause"'; do
    require_pattern "$ledger" "$key"
  done
done

if (( failed )); then
  exit 1
fi

echo 'PASS worker claims are verified against ledgers, footers, and validation'
