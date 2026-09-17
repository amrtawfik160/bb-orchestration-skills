#!/usr/bin/env bash

set -euo pipefail

# Regression: run-status answers "where does the run stand" without touching
# anything. It reads one ledger plus read-only thread and PR state, renders
# the shared format, and stops.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
status="$repo_root/skills/run-status/SKILL.md"
format="$repo_root/skills/run-status/references/format.md"
orchestrator="$repo_root/skills/orchestrate-implementation/SKILL.md"
failed=0

require_pattern() {
  local file=$1
  local pattern=$2

  if ! grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: missing status contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

reject_pattern() {
  local file=$1
  local pattern=$2

  if grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: status must stay read-only, found /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

# Read-only and single-turn.
require_pattern "$status" 'Read-only and single-turn'
require_pattern "$status" 'queue no continuation'
require_pattern "$status" 'spawn nothing'
require_pattern "$status" 'write nothing'
require_pattern "$status" 'Read the ledger, never write it'
require_pattern "$status" 'bb thread tell.*never sent'
require_pattern "$status" 'reported, never repaired'
reject_pattern "$status" 'bb thread spawn'
reject_pattern "$status" 'bb thread tell "\$BB_THREAD_ID"'
reject_pattern "$status" 'write every transition'
reject_pattern "$status" '\[continuation\]'

# One ledger resolved, read-only sources only.
require_pattern "$status" 'orchestrate-implementation/run.json'
require_pattern "$status" 'review-fix-loop/<base7>.json'
require_pattern "$status" 'bb thread count'
require_pattern "$status" 'bb thread list'
require_pattern "$status" 'read-only `gh pr checks` and `gh pr view`'
require_pattern "$status" 'Take no action'

# The format owns the sections and the honesty rule.
require_pattern "$status" 'references/format.md'
require_pattern "$format" '^## Run$'
require_pattern "$format" '^## Tickets$'
require_pattern "$format" '^## Blockers$'
require_pattern "$format" '^## Children$'
require_pattern "$format" 'activeBackgroundAgentCount'
require_pattern "$format" 'never invent one'
require_pattern "$format" 'LOOP_GATE.verdict'
require_pattern "$format" 'VERIFY_GATE.verdict'
require_pattern "$format" 'BLOCKERS: none'
require_pattern "$status" 'a missing gate verdict is a finding'

# The orchestrator status mode renders through this skill.
require_pattern "$orchestrator" 'rendered per `/run-status`'

# The new skill keeps the compactness budget.
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

check_compactness "$status"

if (( failed )); then
  exit 1
fi

echo 'PASS run status reads one ledger and reports without touching anything'
