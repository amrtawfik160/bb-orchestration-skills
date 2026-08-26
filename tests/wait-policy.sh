#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
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

for skill in \
  "$repo_root/skills/orchestrate-implementation/SKILL.md" \
  "$repo_root/skills/review-fix-loop/SKILL.md"
do
  require_pattern "$skill" 'bb thread wait <id> --timeout 1200 --json'
  require_pattern "$skill" 'timeout means the worker is'
  require_pattern "$skill" 'not a failed phase'
  require_pattern "$skill" 'latest event'
  require_pattern "$skill" 'After two'
  require_pattern "$skill" 'send one'
  require_pattern "$skill" 'One more unchanged window pauses'
  require_pattern "$skill" 'user stop'
  require_pattern "$skill" 'pending question'
  require_pattern "$skill" 'Never spawn the next worker before the'

  reject_pattern "$skill" '--timeout 60'
  reject_pattern "$skill" 'Five consecutive timeouts'
  reject_pattern "$skill" 'Do not issue another wait until the user resumes'
done

if (( failed )); then
  exit 1
fi

echo 'PASS timeouts are observations and stalled workers pause after one recovery'
