#!/usr/bin/env bash

set -euo pipefail

# Regression: a pause must be classified, a decision pause must reach the user,
# and only a transient pause may auto-resume.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
protocol="$repo_root/skills/review-fix-loop/references/bb-workers.md"
run_ledger="$repo_root/skills/orchestrate-implementation/references/ledger.md"
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

require_pattern "$protocol" 'Classify every pause'
require_pattern "$protocol" '`transient`'
require_pattern "$protocol" '`decision`'
require_pattern "$protocol" 'rate limit'
require_pattern "$protocol" 'A `decision` pause always reaches the user'
require_pattern "$protocol" 'auto-resume automation'

require_pattern "$protocol" '## Notify'
require_pattern "$protocol" 'bb plugin list \| grep'
require_pattern "$protocol" 'the exact command that continues it'
require_pattern "$protocol" 'With no such'
require_pattern "$protocol" 'the thread report is the notification'

require_pattern "$protocol" '## Auto-resume'
require_pattern "$protocol" 'bb automation create --project'
require_pattern "$protocol" 'bb automation delete'
require_pattern "$protocol" 'delete that automation when the run leaves `paused`'
require_pattern "$protocol" 'only if its ledger pause class is transient'
require_pattern "$protocol" 'auto_resume_count'
require_pattern "$protocol" 'After three that do not'
require_pattern "$protocol" 'reclassify the pause as `decision`'

for ledger in "$run_ledger" "$loop_ledger"; do
  require_pattern "$ledger" '"class"'
  require_pattern "$ledger" 'auto_resume_count'
  require_pattern "$ledger" '`transient` or `decision`'
done
require_pattern "$run_ledger" '"notify"'
require_pattern "$run_ledger" 'auto_resume_automation'

if (( failed )); then
  exit 1
fi

echo 'PASS pauses are classified, decisions notify the user, transients auto-resume'
