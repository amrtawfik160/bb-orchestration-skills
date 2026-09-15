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

# Prose wraps, so match it with line breaks collapsed to single spaces.
require_phrase() {
  local file=$1
  local pattern=$2

  if ! tr '\n' ' ' <"$file" | tr -s ' ' | grep -Eq -- "$pattern"; then
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
protocol="$repo_root/skills/bb-worker-protocol/references/bb-workers.md"

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

for skill in "$orchestrator" "$loop"; do
  require_pattern "$skill" 'required Standards and Spec subagents'
  prompts="$skill"
  [[ "$skill" == "$orchestrator" ]] && prompts="$orchestrator_prompts"
  require_pattern "$repo_root/skills/bb-worker-protocol/references/bb-workers.md" 'End with the attached WORKER_RESULT footer'
  reject_pattern "$skill" 'At most three review attempts'
  reject_pattern "$skill" 'Allow at most two'
  reject_pattern "$skill" 'two fix attempts'
  check_prompt_size "$prompts"

  check_compactness "$skill"
done

# Disclosed prompt files carry the same size budget as inline prompts.
check_prompt_size "$repo_root/skills/codebase-docs-cleanup/references/worker-prompts.md"

# Each half of the protocol stays a single linear read. bb-workers.md hit 550
# once and earned the split into per-worker and between-turns; growth past
# these budgets must earn the next split rather than accrete.
lifecycle="$repo_root/skills/bb-worker-protocol/references/run-lifecycle.md"
for half in "$protocol" "$lifecycle"; do
  half_lines=$(wc -l <"$half")
  if (( half_lines > 320 )); then
    printf 'FAIL %s: %s lines exceeds worker-protocol budget\n' \
      "${half#"$repo_root"/}" "$half_lines"
    failed=1
  fi
done

protocol_lines=$(wc -l <"$protocol")
if (( protocol_lines > 550 )); then
  printf 'FAIL %s: %s lines exceeds worker-protocol budget\n' \
    "${protocol#"$repo_root"/}" "$protocol_lines"
  failed=1
fi

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
require_phrase "$orchestrator" 'missing edges, cycles, or a ticket without acceptance criteria'
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
