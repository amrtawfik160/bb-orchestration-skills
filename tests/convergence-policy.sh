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
      /^## Worker prompts/ || /^# Worker prompts/ { in_prompts = 1; next }
      /^## Gates/ { in_prompts = 0 }
      in_prompts && !in_block && /^```text$/ { in_block = 1; lines = 0; next }
      in_prompts && in_block && /^```$/ { print lines; in_block = 0; next }
      in_prompts && in_block && NF { lines++ }
    ' "$file"
  )
}

orchestrator="$repo_root/skills/orchestrate-implementation/SKILL.md"
orchestrator_prompts="$repo_root/skills/orchestrate-implementation/references/worker-prompts.md"
loop="$repo_root/skills/review-fix-loop/SKILL.md"
protocol="$repo_root/skills/review-fix-loop/references/bb-workers.md"

for skill in "$orchestrator" "$loop"; do
  require_pattern "$skill" 'required Standards and Spec subagents'
  prompts="$skill"
  [[ "$skill" == "$orchestrator" ]] && prompts="$orchestrator_prompts"
  require_pattern "$prompts" 'Every prompt ends with'
  require_pattern "$prompts" 'End with the attached WORKER_RESULT footer'
  reject_pattern "$skill" 'At most three review attempts'
  reject_pattern "$skill" 'Allow at most two'
  reject_pattern "$skill" 'two fix attempts'
  check_prompt_size "$prompts"

  lines=$(wc -l <"$skill")
  if (( lines > 130 )); then
    printf 'FAIL %s: %s lines exceeds compactness budget\n' \
      "${skill#"$repo_root"/}" "$lines"
    failed=1
  fi
done

require_pattern "$loop" 'one orchestrator-spawned BB worker'
require_pattern "$loop" 'Do not invoke /code-review or spawn additional agents'
require_pattern "$loop" '^/code-review <base>$'
require_pattern "$loop" 'CONFIRMED or DISPUTED'
require_pattern "$loop" 'RESOLVED or OPEN'
require_pattern "$loop" 'CONFIRMED_FIX_REGRESSION'
require_pattern "$loop" 'pre-agreed seams'
require_pattern "$loop" 'open root causes'
require_pattern "$loop" 'best-burden'
require_pattern "$loop" 'strictly decreases'
require_pattern "$loop" 'one recovery'
require_pattern "$loop" 'same root cause'
require_pattern "$loop" 'Do not rerun'
require_pattern "$loop" 'no attempt counter'
require_pattern "$loop" 'worker budget caps'
require_pattern "$loop" '^LOOP_GATE:'
require_pattern "$loop" 'verdict: PASS \| PASS_STANDARDS_ONLY \| PAUSED'
reject_pattern "$loop" 'REVIEW_GATE'
reject_pattern "$loop" '/code-review <base> <spec>'
reject_pattern "$loop" 'Standards then Spec sequentially'

# Budgets are safety caps, distinct from convergence rules.
require_pattern "$protocol" 'Budgets are safety caps'

require_pattern "$orchestrator_prompts" '^/implement <attached full ticket>$'
require_pattern "$orchestrator_prompts" '^/diagnosing-bugs$'
require_pattern "$orchestrator" 'Apply `review-fix-loop` directly in this orchestrator'
require_pattern "$orchestrator" 'spawn a loop coordinator'
require_pattern "$orchestrator_prompts" 'gh pr create --draft'
require_pattern "$orchestrator_prompts" 'For the body use /show-me'
reject_pattern "$orchestrator" 'pr-writer'
require_pattern "$orchestrator" 'LOOP_GATE\.verdict: PASS'
require_pattern "$orchestrator" 'tight red reproduction'
require_pattern "$orchestrator" '/improve-codebase-architecture'
require_pattern "$orchestrator" 'raw bugs.*triage|triage.*raw bugs'
require_pattern "$orchestrator" 'missing edges, cycles, or a'
require_pattern "$orchestrator" 'ticket without acceptance criteria'
require_pattern "$orchestrator" 'ready-for-agent'
require_pattern "$orchestrator_prompts" "ticket's seams"
require_pattern "$orchestrator" 'first ready ticket'
require_pattern "$orchestrator" 'parent Spec stays unchanged'
reject_pattern "$orchestrator" 'final integration gate|one integration gate'
reject_pattern "$orchestrator" '25 changed files|2,000 changed lines'
reject_pattern "$loop" '^disable-model-invocation: true$'

if (( failed )); then
  exit 1
fi

echo 'PASS Matt skill contracts compose one review-fix gate per ticket'
