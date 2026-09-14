#!/usr/bin/env bash

set -euo pipefail

# Regression: accepted tickets must not accumulate into one branch and PR, and
# the stack must survive squash merges, failing checks, and review comments.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
orchestrator="$repo_root/skills/orchestrate-implementation/SKILL.md"
orchestrator_prompts="$repo_root/skills/orchestrate-implementation/references/worker-prompts.md"
stack="$repo_root/skills/orchestrate-implementation/references/pr-stack.md"
land="$repo_root/skills/land-stack/SKILL.md"
loop="$repo_root/skills/review-fix-loop/SKILL.md"
readme="$repo_root/README.md"
failed=0

require_pattern() {
  local file=$1
  local pattern=$2

  if ! grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: missing PR contract /%s/\n' "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

# Prose wraps, so match it with line breaks collapsed to single spaces.
require_phrase() {
  local file=$1
  local pattern=$2

  if ! tr '\n' ' ' <"$file" | tr -s ' ' | grep -Eq -- "$pattern"; then
    printf 'FAIL %s: missing PR contract /%s/\n' "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

reject_pattern() {
  local file=$1
  local pattern=$2

  if grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: cumulative PR contract remains /%s/\n' \
      "${file#"$repo_root"/}" "$pattern"
    failed=1
  fi
}

require_phrase "$orchestrator" 'One ticket owns one'
require_phrase "$orchestrator" 'visible BB thread'
require_phrase "$orchestrator" 'one managed worktree'
require_phrase "$orchestrator" 'chains from the previous'
require_phrase "$repo_root/skills/review-fix-loop/references/bb-workers.md" 'never the default'
require_phrase "$repo_root/skills/review-fix-loop/references/subagents.md" 'explicit alternative'
require_phrase "$repo_root/skills/review-fix-loop/references/subagents.md" 'one-ticket diffs'
reject_pattern "$orchestrator" 'subagents\.md'
reject_pattern "$orchestrator" 'shared checkout'
reject_pattern "$orchestrator" 'native sub-agents'
require_phrase "$orchestrator" 'Opening a draft PR and pushing its branch are this'
require_phrase "$orchestrator" 'open or `in review` until its PR merges'
require_phrase "$orchestrator" 'implicit cumulative implementation or final mega-PR'
require_phrase "$orchestrator" 'first ticket branches from the target branch'
require_phrase "$orchestrator" 'later ticket branches from the exact accepted head'
require_phrase "$orchestrator" 'PR targets that previous ticket branch'
require_phrase "$orchestrator" 'pr-base\.\.\.HEAD.*only this ticket'
require_phrase "$orchestrator" 'head equals the reviewed `HEAD`'
require_pattern "$orchestrator" 'references/pr-stack.md'
require_phrase "$orchestrator" 'pause on a failing check'
require_phrase "$orchestrator" 'Set the tracker to `in review`'
require_phrase "$orchestrator" 'push or PR creation fails, pause'
require_phrase "$orchestrator" 'Every accepted'
require_phrase "$orchestrator" 'ticket must have one PR URL'
require_phrase "$orchestrator_prompts" 'For the body use /show-me'
require_phrase "$orchestrator_prompts" 'gh pr create --draft'

# Cumulative-run recovery moved to its own reference and must stay intact.
recovery="$repo_root/skills/orchestrate-implementation/references/recovery.md"
require_pattern "$orchestrator" 'references/recovery.md'
require_phrase "$recovery" 'without rewriting commits'
require_pattern "$recovery" 'git branch "<ticket-branch>" "<accepted-head>"'
require_phrase "$recovery" 'targeting the previous ticket branch'
require_phrase "$recovery" 'patch-ID comparison'
require_phrase "$recovery" 'cannot be proved'

reject_pattern "$orchestrator" 'Reuse one cumulative environment'
reject_pattern "$orchestrator" 'mark it complete through the tracker'
reject_pattern "$orchestrator" 'Push, PR, merge, deploy, archive, and cleanup require separate requests'

# Stack maintenance after a PR opens.
# Checks are swept, never watched: CI outlives the turn that opened the PR.
require_pattern "$stack" 'gh pr view "\$URL" --json statusCheckRollup'
require_pattern "$stack" 'Never use `gh pr checks --watch` here'
reject_pattern "$stack" 'gh pr checks "\$URL" --watch'
require_pattern "$stack" 'The check sweep'
require_pattern "$stack" 'No PR stays recorded as'
require_pattern "$stack" 'gh pr ready'
require_pattern "$stack" '`none`'

# A red target branch is inherited, not caused, and must not strand the stack.
require_pattern "$stack" '## The CI baseline'
require_pattern "$stack" 'select\(.conclusion == "failure"\)'
require_pattern "$stack" 'baseline_fail'
require_pattern "$stack" 'never blocks this run|inherited, not caused'
require_pattern "$orchestrator" 'ci_baseline'
require_pattern "$land" 'outside the run.s `ci_baseline`'
require_pattern "$stack" 'git merge-base --is-ancestor "\$PARENT_ACCEPTED_HEAD" "origin/\$TARGET"'
require_phrase "$stack" 'squash or rebase merge rewrote'
require_pattern "$stack" 'git rebase --onto origin/<target> <parent-accepted-head> <child-branch>'
require_pattern "$stack" '--force-with-lease'
require_pattern "$stack" 'gh pr edit "\$CHILD_URL" --base "\$TARGET"'
require_pattern "$stack" 'git patch-id --stable'
require_pattern "$stack" 'retarget'
require_pattern "$stack" '## Human review comments'
require_pattern "$stack" '--from-pr'
require_phrase "$stack" 'oldest first'

require_phrase "$loop" 'caller owns branch push and PR creation'
require_pattern "$loop" 'LOOP_GATE'
require_pattern "$loop" '--from-pr <url>'
reject_pattern "$loop" '^disable-model-invocation: true$'
require_phrase "$readme" 'One draft PR per accepted ticket'
require_phrase "$readme" 'there is no implicit final mega-PR'

if (( failed )); then
  exit 1
fi

echo 'PASS every accepted ticket has an isolated branch and PR boundary'
