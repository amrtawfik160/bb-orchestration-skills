#!/usr/bin/env bash

set -euo pipefail

# Regression: the wait protocol lives in one shared reference, and both skills
# point at it instead of restating it.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
protocol="$repo_root/skills/bb-worker-protocol/references/bb-workers.md"
orchestrator="$repo_root/skills/orchestrate-implementation/SKILL.md"
loop="$repo_root/skills/review-fix-loop/SKILL.md"
failed=0

require_pattern() {
  local file=$1
  local pattern=$2

  if ! grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: missing wait contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

reject_pattern() {
  local file=$1
  local pattern=$2

  if grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: obsolete wait contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

require_pattern "$protocol" 'bb thread wait "\$WORKER" --timeout 1200 --json'
require_pattern "$protocol" '2 timeout'
# Exit 1 is a bad ID or an unreachable server, never a slow worker.
require_pattern "$protocol" '1 error'
require_pattern "$protocol" 'Exit 1 is not a slow worker'
require_pattern "$protocol" 'timeout means the worker is'
require_pattern "$protocol" 'not a failed phase'
require_pattern "$protocol" 'Listen; never poll'
require_pattern "$protocol" 'lifecycle notifications'
require_pattern "$protocol" 'Never read the worker log while waiting'
require_pattern "$protocol" 'Never ask'
require_pattern "$protocol" 'Each timeout consumes 20 minutes'
require_pattern "$protocol" 'Stopped manually'
require_pattern "$protocol" 'Never respawn past a user stop'
require_pattern "$protocol" 'bb thread retry'
require_pattern "$protocol" 'A pending interaction is handled'
require_pattern "$protocol" 'user stop'
require_pattern "$protocol" 'Never spawn the next worker before the'
require_pattern "$protocol" '--visibility visible'
require_pattern "$protocol" 'bb thread stop'
require_pattern "$protocol" 'forward the question to the user verbatim and pause'
require_pattern "$protocol" 'interactions answer'
require_pattern "$protocol" '## Pause'
require_pattern "$protocol" 'state: paused'
require_pattern "$protocol" '## Budgets'
require_pattern "$protocol" 'reason: budget'

reject_pattern "$protocol" '--timeout 60([^0-9]|$)'
reject_pattern "$protocol" 'Five consecutive timeouts'
reject_pattern "$protocol" '--visibility hidden'
reject_pattern "$protocol" 'unchanged window'
reject_pattern "$protocol" 'window of evidence'
reject_pattern "$protocol" 'Report your status'
reject_pattern "$protocol" 'after-seq'
reject_pattern "$protocol" 'LAST_SEQ'

# Both skills point at the protocol instead of restating it.
require_pattern "$loop" 'references/bb-workers.md'
require_pattern "$orchestrator" '\.\./bb-worker-protocol/references/bb-workers.md'
for skill in "$orchestrator" "$loop"; do
  reject_pattern "$skill" '^## Wait'
  reject_pattern "$skill" 'bb thread wait <id>'
  reject_pattern "$skill" 'Do not issue another wait until the user resumes'
done

if (( failed )); then
  exit 1
fi

echo 'PASS one shared worker protocol defines waits, interactions, budgets, and pauses'
