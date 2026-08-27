#!/usr/bin/env bash

set -euo pipefail

# Regression: #937 needed progressing fixes beyond the old two-attempt limit.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
failed=0

require_pattern() {
  local file=$1
  local pattern=$2

  if ! grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: missing contract /%s/\n' "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

reject_pattern() {
  local file=$1
  local pattern=$2

  if grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: obsolete contract /%s/\n' "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

check_prompt_size() {
  local file=$1
  local block_lines

  while read -r block_lines; do
    if (( block_lines > 4 )); then
      printf 'FAIL %s: worker prompt has %s non-empty lines\n' \
        "${file#"$repo_root"/}" "$block_lines"
      failed=1
    fi
  done < <(
    awk '
      /^## Worker prompts/ { in_prompts = 1; next }
      /^## Gates/ { in_prompts = 0 }
      in_prompts && !in_block && /^```text$/ { in_block = 1; lines = 0; next }
      in_prompts && in_block && /^```$/ { print lines; in_block = 0; next }
      in_prompts && in_block && NF { lines++ }
    ' "$file"
  )
}

for skill in \
  "$repo_root/skills/orchestrate-implementation/SKILL.md" \
  "$repo_root/skills/review-fix-loop/SKILL.md"
do
  require_pattern "$skill" 'one orchestrator-spawned BB worker'
  require_pattern "$skill" 'required Standards and Spec subagents'
  require_pattern "$skill" 'Do not invoke /code-review or spawn additional agents'
  require_pattern "$skill" '^/code-review <base>$'
  require_pattern "$skill" '^##? Finding check|^Finding check:'
  require_pattern "$skill" 'CONFIRMED or DISPUTED'
  require_pattern "$skill" '^##? Closure check|^Closure check:'
  require_pattern "$skill" 'RESOLVED or OPEN'
  require_pattern "$skill" 'CONFIRMED_FIX_REGRESSION'
  require_pattern "$skill" 'regressions caused by the fix'
  require_pattern "$skill" 'pre-agreed seams'
  require_pattern "$skill" 'open root causes'
  require_pattern "$skill" 'best-burden'
  require_pattern "$skill" 'strictly decreases'
  require_pattern "$skill" 'one recovery'
  require_pattern "$skill" 'same root cause'
  require_pattern "$skill" 'Do not rerun|instead of rerunning'

  reject_pattern "$skill" 'REVIEW_GATE'
  reject_pattern "$skill" '/code-review <base> <spec>'
  reject_pattern "$skill" 'Standards then Spec sequentially'
  reject_pattern "$skill" 'At most three review attempts'
  reject_pattern "$skill" 'Allow at most two'
  reject_pattern "$skill" 'two fix attempts'
  reject_pattern "$skill" 'Fix the attached findings with `/tdd` where useful'

  check_prompt_size "$skill"

  lines=$(wc -l <"$skill")
  if (( lines > 130 )); then
    printf 'FAIL %s: %s lines exceeds compactness budget\n' \
      "${skill#"$repo_root"/}" "$lines"
    failed=1
  fi
done

orchestrator="$repo_root/skills/orchestrate-implementation/SKILL.md"
loop="$repo_root/skills/review-fix-loop/SKILL.md"

require_pattern "$orchestrator" '^/implement <full ticket or spec reference>$'
require_pattern "$orchestrator" '^/diagnosing-bugs$'
require_pattern "$orchestrator" 'Route by uncertainty'
require_pattern "$orchestrator" 'tight, red-capable command'
require_pattern "$orchestrator" '/improve-codebase-architecture'
require_pattern "$orchestrator" 'raw.*bug.*triage|triage.*raw.*bug'
require_pattern "$orchestrator" 'already sized for one fresh context'
require_pattern "$orchestrator" 'missing edges or cycles'
require_pattern "$orchestrator" 'frontier is empty'
require_pattern "$orchestrator" 'stalled behavioral defect.*diagnosing-bugs|diagnosing-bugs.*stalled behavioral defect'
require_pattern "$orchestrator" 'mark it complete through the'
require_pattern "$orchestrator" 'leave the parent Spec unchanged'
reject_pattern "$orchestrator" '25 changed files|2,000 changed lines'

reject_pattern "$loop" '^/implement'
require_pattern "$loop" 'stalled behavioral defect.*diagnosing-bugs|diagnosing-bugs.*stalled behavioral defect'
require_pattern "$loop" 'Standards-only run'
require_pattern "$loop" 'never call that a two-axis pass'

if (( failed )); then
  exit 1
fi

echo 'PASS Matt skill contracts are composed without an unbounded review loop'
