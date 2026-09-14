#!/usr/bin/env bash

set -euo pipefail

# Regression: flakes quarantine with a ticket instead of looping, cycling
# findings pause with a diagnosis bundle, and converging work still runs to
# zero with no attempt counter.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
loop="$repo_root/skills/review-fix-loop/SKILL.md"
quarantine="$repo_root/skills/review-fix-loop/references/quarantine.md"
loop_ledger="$repo_root/skills/review-fix-loop/references/ledger.md"
land="$repo_root/skills/land-stack/SKILL.md"
verify="$repo_root/skills/verify-landing/SKILL.md"
failed=0

require_pattern() {
  local file=$1
  local pattern=$2

  if ! grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: missing quarantine contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

# The loop logs attempts and points at the quarantine record.
require_pattern "$loop" 'logging'
require_pattern "$loop" 'each attempt per `references/quarantine.md`'
require_pattern "$loop" 'twice-reopened IDs per `references/quarantine.md`'

# Flake patterns are exact and provable from the ledger.
require_pattern "$quarantine" 'Re-run green'
require_pattern "$quarantine" 'green on an immediate re-run'
require_pattern "$quarantine" 'with no code change between'
require_pattern "$quarantine" 'Alternating'
require_pattern "$quarantine" 'red, green, red across three'
require_pattern "$quarantine" 'consecutive fix commits'

# Quarantine records, files, notifies, and gates honestly.
require_pattern "$quarantine" 'Record `quarantine\[\]`'
require_pattern "$quarantine" "ready-for-agent.*labeled \`flaky\`"
require_pattern "$quarantine" 'continues without it'
require_pattern "$quarantine" 'a quarantine without a ticket is a skipped check'
require_pattern "$quarantine" 'Unquarantine only on human ack'
require_pattern "$quarantine" 're-measure before trusting'

# The reopen budget caps cycling, not converging work.
require_pattern "$quarantine" 'returns RESOLVED to OPEN twice'
require_pattern "$quarantine" 'is cycling, not'
require_pattern "$quarantine" 'diagnosis bundle'
require_pattern "$quarantine" 'still has no attempt counter'
require_pattern "$quarantine" 'still runs to zero under the worker budget'

# Gates inherit both baseline and quarantine, and report which.
require_pattern "$quarantine" 'Baseline versus quarantine'
require_pattern "$quarantine" 'proven flaky mid-run'
require_pattern "$land" 'outside the run.s `ci_baseline` or the loop quarantine'
require_pattern "$land" 'reported'
require_pattern "$land" 'with its ticket and merges the same way'
require_pattern "$verify" 'and quarantine'

# The loop ledger carries attempts and quarantine.
require_pattern "$loop_ledger" '"attempts"'
require_pattern "$loop_ledger" '"fix_head"'
require_pattern "$loop_ledger" '"quarantine"'
require_pattern "$loop_ledger" '"pattern"'

if (( failed )); then
  exit 1
fi

echo 'PASS flakes quarantine with tickets and cycling findings pause with evidence'
