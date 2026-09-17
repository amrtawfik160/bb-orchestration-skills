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
protocol="$repo_root/skills/bb-worker-protocol/references/run-lifecycle.md"
lifecycle="$repo_root/skills/bb-worker-protocol/references/run-lifecycle.md"
orchestrator="$repo_root/skills/orchestrate-implementation/SKILL.md"
stack="$repo_root/skills/bb-worker-protocol/references/pr-stack.md"
ledger="$repo_root/skills/bb-worker-protocol/references/run-ledger.md"
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
require_pattern "$lifecycle" '## Continue the run'
require_pattern "$lifecycle" 'Ending a turn is not pausing'
require_pattern "$lifecycle" 'may end only in a terminal state'
require_pattern "$protocol" "bb thread tell \"\\\$BB_THREAD_ID\" '\[continuation\]"
require_pattern "$lifecycle" '\[continuation\] orchestrate-implementation'
require_pattern "$lifecycle" '\[continuation\] land-stack'
require_pattern "$lifecycle" '\[continuation\] verify-landing'
require_pattern "$lifecycle" '\[continuation\] review-fix-loop'
require_pattern "$lifecycle" '\[continuation\] codebase-docs-cleanup'
require_pattern "$lifecycle" 'as the turn ends, not as it starts'
reject_pattern "$protocol" 'as soon as the turn starts'
require_pattern "$lifecycle" 'queue delete'
require_pattern "$repo_root/skills/bb-worker-protocol/references/run-lifecycle.md" 'A run outlives one turn'
require_pattern "$ledger" 'continuation_message'

# Wakes never stack, stale rows clear, and a terminal wake ends silently.
require_pattern "$lifecycle" 'select\(.content'
require_pattern "$lifecycle" 'end the turn silently'
require_pattern "$lifecycle" 'safe to ignore'

# The continuation is a loop, so it needs its own caps.
require_pattern "$lifecycle" 'no_progress'
require_pattern "$lifecycle" 'Two consecutive'
require_pattern "$ledger" 'since_last_transition'
require_pattern "$ledger" 'run_workers'
require_pattern "$ledger" 'continuations'

# A turn with nothing to do but wait must not spin. thr_svfvm2xg6t completed a
# turn every 25-30 seconds for hours, each one re-sweeping one PR and
# re-queueing itself, because an immediate continuation plus a sweep that
# counted as a transition made the loop legal.
require_pattern "$lifecycle" 'Never end a turn while a worker is active'
require_pattern "$lifecycle" '\[continuation\].*--send-at 10m'
require_pattern "$lifecycle" 'unchanged sweep is not a transition'
require_pattern "$lifecycle" 'nothing pending'

# A queued continuation can be lost without dispatching, so a running ledger
# needs a delayed `[watchdog]` tell on the same thread, not only a paused one.
require_pattern "$lifecycle" '## Watchdog'
require_pattern "$lifecycle" 'idle with an empty queue'
require_pattern "$lifecycle" '\[watchdog\].*read run.json'
require_pattern "$lifecycle" '--mode queue --send-at 10m'
require_pattern "$lifecycle" 'codebase-docs-cleanup/run.json'
require_pattern "$lifecycle" 'review-fix-loop/<base7>.json'
require_pattern "$ledger" 'watchdog_message'
require_pattern "$orchestrator" 'watchdog'
require_pattern "$lifecycle" 'manual-stop'
reject_pattern "$lifecycle" 'bb automation'
reject_pattern "$ledger" '"watchdog_automation"'
reject_pattern "$ledger" '"auto_resume_automation"'

# One thread cannot hold a long run.
require_pattern "$lifecycle" '## Relay to a successor'
require_pattern "$lifecycle" 'contextWindowUsage'
require_pattern "$lifecycle" 'bb thread context --self --json'
require_pattern "$lifecycle" 'Never fork for this'
require_pattern "$lifecycle" 'Continue this <skill> run from the attached ledger'
require_pattern "$lifecycle" 'relay.predecessor'
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
validation="$repo_root/skills/bb-worker-protocol/references/validation.md"
require_pattern "$validation" 'Rerun the affected suite'
require_pattern "$validation" 'time, clocks, concurrency'
require_pattern "$orchestrator" 'repeat_validation'
require_pattern "$ledger" 'repeat_validation'

# A pause without a class reaches nobody and clears itself never.
require_pattern "$lifecycle" '`class` is never omitted'
require_pattern "$lifecycle" 'written without `class` is a `decision` pause'

# A notify command that does not run is not a notification.
require_pattern "$lifecycle" 'notify.verified'
require_pattern "$lifecycle" 'Probe the match once'
require_pattern "$ledger" '"verified"'

# Runs wake with bb thread tell / wait. No skill in this bundle creates a
# scheduled sidecar.
if grep -RInE --include='*.md' -- 'bb automation' "$repo_root/skills" "$repo_root/README.md"; then
  printf 'FAIL skills still mention bb automation\n'
  failed=1
fi

if (( failed )); then
  exit 1
fi

echo 'PASS runs continue across turns, survive a red baseline, and record every gate'
