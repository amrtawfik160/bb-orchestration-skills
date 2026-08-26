#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
failed=0

require_text() {
  local file=$1
  local text=$2
  local normalized

  normalized=$(tr '\n' ' ' <"$file" | tr -s '[:space:]' ' ')

  if [[ $normalized != *"$text"* ]]; then
    printf 'FAIL %s: missing %s\n' "${file#"$repo_root"/}" "$text"
    failed=1
  fi
}

reject_text() {
  local file=$1
  local text=$2
  local normalized

  normalized=$(tr '\n' ' ' <"$file" | tr -s '[:space:]' ' ')

  if [[ $normalized == *"$text"* ]]; then
    printf 'FAIL %s: contains obsolete policy %s\n' "${file#"$repo_root"/}" "$text"
    failed=1
  fi
}

for skill in \
  "$repo_root/skills/orchestrate-implementation/SKILL.md" \
  "$repo_root/skills/review-fix-loop/SKILL.md"
do
  require_text "$skill" 'bb thread wait <id> --timeout 60 --json'
  require_text "$skill" 'Waiting is bounded observation'
  require_text "$skill" 'heartbeat'
  require_text "$skill" 'Five consecutive timeouts'
  require_text "$skill" 'one corrective `tell`'
  require_text "$skill" 'asked only to wait'
  require_text "$skill" 'Do not issue another wait until the user resumes'
  require_text "$skill" 'pause and report'
  reject_text "$skill" 'A timeout keeps waiting'
  reject_text "$skill" '--timeout 600'
  reject_text "$skill" '--timeout 3600'
done

if (( failed )); then
  exit 1
fi

echo 'PASS wait policy is bounded, observable, and recoverable'
