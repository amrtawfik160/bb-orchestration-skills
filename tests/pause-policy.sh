#!/usr/bin/env bash

set -euo pipefail

# Regression: a pause must be classified, a decision pause must reach the user,
# and only a transient pause may auto-resume.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
protocol="$repo_root/skills/bb-worker-protocol/references/bb-workers.md"
lifecycle="$repo_root/skills/bb-worker-protocol/references/run-lifecycle.md"
run_ledger="$repo_root/skills/bb-worker-protocol/references/run-ledger.md"
loop_ledger="$repo_root/skills/review-fix-loop/references/ledger.md"
failed=0

require_pattern() {
  local file=$1
  local pattern=$2

  if ! grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: missing pause contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

reject_pattern() {
  local file=$1
  local pattern=$2

  if grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: obsolete pause contract /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

require_pattern "$lifecycle" 'Classify every pause'
require_pattern "$lifecycle" '`transient`'
require_pattern "$lifecycle" '`decision`'
require_pattern "$lifecycle" 'rate limit'
require_pattern "$lifecycle" 'A `decision` pause always reaches the user'
reject_pattern "$lifecycle" 'auto-resume automation'

require_pattern "$lifecycle" '## Notify'
require_pattern "$lifecycle" 'bb plugin list \| grep'
require_pattern "$lifecycle" 'the exact command that continues it'
require_pattern "$lifecycle" 'With no such'
require_pattern "$lifecycle" 'the thread report is the notification'

# A decision pause must be reachable: workers are visible by default.
require_pattern "$lifecycle" 'Workers are visible, so the user can reach one from the sidebar'
require_pattern "$lifecycle" 'blames a specific worker, open it'
require_pattern "$lifecycle" 'bb thread open "\$WORKER"'

require_pattern "$lifecycle" '## Auto-resume'
require_pattern "$lifecycle" 'leaves nothing to clean up'
require_pattern "$lifecycle" 'queue the same `--send-at 15m`'
reject_pattern "$lifecycle" 'bb automation'
require_pattern "$lifecycle" 'only if its ledger pause class is transient'
require_pattern "$lifecycle" 'auto_resume_count'
require_pattern "$lifecycle" 'After three that do not'
require_pattern "$lifecycle" 'reclassify the pause as `decision`'

for ledger in "$run_ledger" "$loop_ledger"; do
  require_pattern "$ledger" '"class"'
  require_pattern "$ledger" 'auto_resume_count'
  require_pattern "$ledger" '`transient` or `decision`'
done
require_pattern "$run_ledger" '"notify"'
require_pattern "$run_ledger" 'auto_resume_message'
require_pattern "$run_ledger" 'watchdog_message'
reject_pattern "$run_ledger" '"auto_resume_automation"'

if (( failed )); then
  exit 1
fi

echo 'PASS pauses are classified, decisions notify the user, transients auto-resume'
