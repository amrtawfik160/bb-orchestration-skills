#!/usr/bin/env bash

set -euo pipefail

# Regression: landing proves the merges, verification proves the target. Every
# landed merge gets green merge-commit checks plus smoke validation, and a red
# target gets a revert-first response, never silence.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
verify="$repo_root/skills/verify-landing/SKILL.md"
redmain="$repo_root/skills/verify-landing/references/red-main.md"
land="$repo_root/skills/land-stack/SKILL.md"
ledger="$repo_root/skills/bb-worker-protocol/references/run-ledger.md"
protocol="$repo_root/skills/bb-worker-protocol/references/bb-workers.md"
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
# Compactness. Measured in words, not lines: a line budget charges a numbered
# checklist more than the paragraph it replaced, which is backwards, since the
# checklist is the more scannable of the two. The budget also measures procedure
# only. A rationalization table is enforcement, useful exactly where an agent is
# already rationalizing, so it stays inline under its own cap rather than
# competing with the steps for the same allowance.
check_compactness() {
  local file=$1
  local rules table flags
  rules=$(awk '/^## (Rationalizations|Red flags)/ {skip = 1; next}
               /^## / {skip = 0}
               !skip' "$file" | wc -w)
  table=$(awk '/^## Rationalizations/ {on = 1; next} /^## / {on = 0} on && /^\| / ' "$file" | wc -l)
  flags=$(awk '/^## Red flags/ {on = 1; next} /^## / {on = 0} on && /^- / ' "$file" | wc -l)

  if (( rules > 1100 )); then
    printf 'FAIL %s: %s procedure words exceeds compactness budget\n' \
      "${file#"$repo_root"/}" "$rules"
    failed=1
  fi
  # Header plus separator plus at most twelve excuses.
  if (( table > 14 )); then
    printf 'FAIL %s: %s rationalization rows exceeds its cap\n' \
      "${file#"$repo_root"/}" "$table"
    failed=1
  fi
  if (( flags > 8 )); then
    printf 'FAIL %s: %s red flags exceeds its cap\n' \
      "${file#"$repo_root"/}" "$flags"
    failed=1
  fi
}

check_compactness "$verify"

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
