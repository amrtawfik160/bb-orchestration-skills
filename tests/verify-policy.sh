#!/usr/bin/env bash

set -euo pipefail

# Regression: landing proves the merges, verification proves the target. Every
# landed merge gets green merge-commit checks plus smoke validation, and a red
# target gets a revert-first response, never silence.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
verify="$repo_root/skills/verify-landing/SKILL.md"
redmain="$repo_root/skills/verify-landing/references/red-main.md"
land="$repo_root/skills/land-stack/SKILL.md"
ledger="$repo_root/skills/orchestrate-implementation/references/ledger.md"
protocol="$repo_root/skills/review-fix-loop/references/bb-workers.md"
failed=0

require_pattern() {
  local file=$1
  local pattern=$2

  if ! grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: missing verification contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

reject_pattern() {
  local file=$1
  local pattern=$2

  if grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: unsafe verification contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

# Order, workers, and gating.
require_pattern "$verify" 'Verify oldest first'
require_pattern "$verify" 'oldest unverified ticket'
require_pattern "$verify" 'fresh visible BB thread in one verify environment'
require_pattern "$verify" 'merge-commit checks'
require_pattern "$verify" 'commits/<merge-sha>/check-runs'
require_pattern "$verify" 'Resolve `smoke`'
require_pattern "$verify" 'outside the run.s `ci_baseline` and quarantine'
require_pattern "$verify" 'references/red-main.md'
require_pattern "$verify" 'state: landed'
require_pattern "$verify" 'A run outlives one turn'

# The gate footer names its own verdict.
require_pattern "$verify" '^VERIFY_GATE:'
require_pattern "$verify" 'verdict: VERIFIED \| PAUSED'
require_pattern "$verify" 'open_response_tickets'
require_pattern "$verify" 'verification.state: verified'
require_pattern "$verify" 'Proven merges stay proven'
require_pattern "$verify" 'starts at the first unverified ticket'

# --land hands off to this skill, so it must stay model-invocable.
reject_pattern "$verify" '^disable-model-invocation: true$'
require_pattern "$land" '/verify-landing <ledger path>'
require_pattern "$land" 'verification proves the target'
require_pattern "$protocol" '\[continuation\] verify-landing'

# Red-main response: classify, revert first by default, record, notify.
require_pattern "$redmain" 'Silence is the only forbidden move'
require_pattern "$redmain" 'Neither is a red target'
require_pattern "$redmain" 'reverts the merge commit in a managed'
require_pattern "$redmain" 'opens a revert PR against the target'
require_pattern "$redmain" 'merges only through the `land-stack` gate'
require_pattern "$redmain" 'ready-for-agent.*ticket with the failure evidence'
require_pattern "$redmain" 'if it slips past one cycle, revert first'
require_pattern "$redmain" 'verification.response'

# Ledger carries the verification record.
require_pattern "$ledger" '"verification"'
require_pattern "$ledger" '"verified_at"'
require_pattern "$ledger" 'verification.state.*pending.*running.*paused.*verified'

# The new skill keeps the compactness budget and the four-line prompt budget.
lines=$(wc -l <"$verify")
if (( lines > 130 )); then
  printf 'FAIL %s: %s lines exceeds compactness budget\n' \
    "${verify#"$repo_root"/}" "$lines"
  failed=1
fi

while read -r block_lines; do
  if (( block_lines > 4 )); then
    printf 'FAIL %s: worker prompt has %s non-empty lines\n' \
      "${verify#"$repo_root"/}" "$block_lines"
    failed=1
  fi
done < <(
  awk '
    !in_block && /^```text$/ { in_block = 1; lines = 0; next }
    in_block && /^```$/ { print lines; in_block = 0; next }
    in_block && NF { lines++ }
  ' "$verify"
)

if (( failed )); then
  exit 1
fi

echo 'PASS landed merges verify green on the target, and red targets get a response'
