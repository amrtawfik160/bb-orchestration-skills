#!/usr/bin/env bash

set -euo pipefail

# Regression: two real runs stranded mid-graph. Each assertion below pins the
# gap that stranded them, so a future edit cannot quietly reopen one.
#
#   thr_crgqjihta3: 8 of 19 tickets, 52 human turns, state still `running`
#                   with no pause and no queued continuation. Seven PRs left
#                   at `checks: pending`, none marked ready.
#   thr_qanmy8ufx3: 1 of 16 tickets, paused on a check that also fails on the
#                   target branch, with a pause record carrying no `class`.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
protocol="$repo_root/skills/review-fix-loop/references/bb-workers.md"
orchestrator="$repo_root/skills/orchestrate-implementation/SKILL.md"
stack="$repo_root/skills/orchestrate-implementation/references/pr-stack.md"
ledger="$repo_root/skills/orchestrate-implementation/references/ledger.md"
land="$repo_root/skills/land-stack/SKILL.md"
failed=0

require_pattern() {
  local file=$1
  local pattern=$2

  if ! grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: missing continuity contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

reject_pattern() {
  local file=$1
  local pattern=$2

  if grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: obsolete continuity contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

# A turn must not end with work left and nothing queued.
require_pattern "$protocol" '## Continue the run'
require_pattern "$protocol" 'Ending a turn is not pausing'
require_pattern "$protocol" 'may end only in a terminal state'
require_pattern "$protocol" "bb thread tell \"\\\$BB_THREAD_ID\" '\[continuation\]"
require_pattern "$protocol" '\[continuation\] orchestrate-implementation'
require_pattern "$protocol" '\[continuation\] land-stack'
require_pattern "$protocol" '\[continuation\] verify-landing'
require_pattern "$protocol" '\[continuation\] review-fix-loop'
require_pattern "$protocol" '\[continuation\] codebase-docs-cleanup'
require_pattern "$protocol" 'as the turn ends, not as it starts'
reject_pattern "$protocol" 'as soon as the turn starts'
require_pattern "$protocol" 'queue delete'
require_pattern "$orchestrator" 'A run outlives one turn'
require_pattern "$ledger" 'continuation_message'

# Wakes never stack, stale rows clear, and a terminal wake ends silently.
require_pattern "$protocol" 'select\(.content'
require_pattern "$protocol" 'end the turn silently'
require_pattern "$protocol" 'safe to ignore'

# The continuation is a loop, so it needs its own caps.
require_pattern "$protocol" 'no_progress'
require_pattern "$protocol" 'Two consecutive'
require_pattern "$ledger" 'since_last_transition'
require_pattern "$ledger" 'run_workers'
require_pattern "$ledger" 'continuations'

# A turn with nothing to do but wait must not spin. thr_svfvm2xg6t completed a
# turn every 25-30 seconds for hours, each one re-sweeping one PR and
# re-queueing itself, because an immediate continuation plus a sweep that
# counted as a transition made the loop legal.
require_pattern "$protocol" 'Never end a turn while a worker is active'
require_pattern "$protocol" '\[continuation\].*--send-at 10m'
require_pattern "$protocol" 'unchanged sweep is not a transition'
require_pattern "$protocol" 'nothing pending'

# A queued continuation can be lost without dispatching, so a running ledger
# needs an external watchdog, not only a paused one.
require_pattern "$protocol" '## Watchdog'
require_pattern "$protocol" 'idle with an empty queue'
require_pattern "$protocol" 'bb automation create --project "\$BB_PROJECT_ID" --name "watchdog'
require_pattern "$protocol" 'codebase-docs-cleanup/run.json'
require_pattern "$protocol" 'review-fix-loop/\*.json'
require_pattern "$ledger" 'watchdog_automation'
require_pattern "$orchestrator" 'watchdog'
require_pattern "$protocol" 'manual-stop'

# One thread cannot hold a long run.
require_pattern "$protocol" '## Relay to a successor'
require_pattern "$protocol" 'contextWindowUsage'
require_pattern "$protocol" 'bb thread context --self --json'
require_pattern "$protocol" 'Never fork for this'
require_pattern "$protocol" 'Continue this <skill> run from the attached ledger'
require_pattern "$protocol" 'relay.predecessor'
require_pattern "$ledger" 'relay.successor|"relay"'

# A red target branch is inherited, not caused.
require_pattern "$stack" '## The CI baseline'
require_pattern "$stack" 'inherited, not caused'
require_pattern "$orchestrator" 'ci_baseline'
require_pattern "$ledger" 'ci_baseline'
require_pattern "$ledger" 'baseline_fail'
require_pattern "$land" "outside the run's .ci_baseline"

# Checks are swept, never watched, and never left pending.
require_pattern "$stack" '## The check sweep'
require_pattern "$stack" 'Never use `gh pr checks --watch` here'
require_pattern "$stack" 'No PR stays recorded as'

# An unwritten review gate is a skipped review gate.
require_pattern "$orchestrator" 'tickets.<id>.loop.gate'
require_pattern "$orchestrator" 'an unwritten gate is a skipped gate'
require_pattern "$ledger" '"gate"'
require_pattern "$ledger" 'absent verdict blocks the PR'

# One green run cannot tell a passing test from a flaky one.
require_pattern "$orchestrator" 'Repeat the affected suite'
require_pattern "$orchestrator" 'time, clocks, concurrency'
require_pattern "$ledger" 'repeat_validation'

# A pause without a class reaches nobody and clears itself never.
require_pattern "$protocol" '`class` is never omitted'
require_pattern "$protocol" 'written without `class` is a `decision` pause'

# A notify command that does not run is not a notification.
require_pattern "$protocol" 'notify.verified'
require_pattern "$protocol" 'Probe the match once'
require_pattern "$ledger" '"verified"'

if (( failed )); then
  exit 1
fi

echo 'PASS runs continue across turns, survive a red baseline, and record every gate'
