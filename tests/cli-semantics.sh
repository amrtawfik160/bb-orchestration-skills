#!/usr/bin/env bash

set -euo pipefail

# Drift guard: the worker protocol relies on documented bb behaviour, not just
# on flags existing. Each check below pins one fact the protocol depends on, so
# a bb release that changes the fact fails here instead of in a live run.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
protocol="$repo_root/skills/bb-worker-protocol/references/bb-workers.md"
lifecycle="$repo_root/skills/bb-worker-protocol/references/run-lifecycle.md"
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
  local why=$3

  if grep -Eq -- "$pattern" "$file"; then
    printf 'FAIL %s: /%s/ %s\n' "${file#"$repo_root"/}" "$pattern" "$why"
    failed=1
  fi
}

# The orchestrator listens for workers instead of polling them: one blocking
# wait covers a phase, and no wait path pages the worker log or nudges it.
require_pattern "$protocol" 'Listen; never poll'
require_pattern "$protocol" 'Never read the worker log while waiting'
reject_pattern "$protocol" 'after-seq' \
  'the wait path pages no worker log'
reject_pattern "$protocol" 'LAST_SEQ' \
  'no sequence is tracked without paging'
reject_pattern "$protocol" 'Report your status' \
  'workers are never nudged for status'

# A committed ticket branch reports workingTree.state committed_unmerged, so
# the clean check must read hasUncommittedChanges.
require_pattern "$protocol" 'workStatus\.workingTree\.hasUncommittedChanges'
reject_pattern "$protocol" 'workingTree\.state\s*==\s*"clean"' \
  'never holds for a committed ticket branch'

# The terminal exit code lives on the session record, not in wait or output.
require_pattern "$protocol" 'bb terminal wait "\$TERMINAL" --exit'
require_pattern "$protocol" 'bb terminal show "\$TERMINAL" --json'
require_pattern "$protocol" 'exitCode'

# A worker can be held rather than stalled, and a retry can already be queued.
require_pattern "$protocol" 'bb thread queue list'
require_pattern "$protocol" 'waitingOn'
require_pattern "$protocol" 'retry_already_queued'

# Both permission ceilings, and attachments that must exist on the worker's host.
require_pattern "$protocol" 'maxPermissionMode'
require_pattern "$protocol" 'bb project attachment upload'

# Workers are visible and openable; legacy hidden workers promote and count differently.
require_pattern "$lifecycle" 'bb thread update "\$WORKER" --visibility visible'
require_pattern "$lifecycle" 'bb thread open "\$WORKER"'
require_pattern "$protocol" 'exclude\s+hidden threads'

# Transient resume is a `--send-at` tell on this thread; a still-transient
# wake queues another.
require_pattern "$lifecycle" '--send-at 15m'
require_pattern "$lifecycle" 'bb thread queue delete'
require_pattern "$lifecycle" 'queue the same `--send-at 15m`'
require_pattern "$protocol" 'bb thread list --parent-thread'

if ! command -v bb >/dev/null 2>&1; then
  echo 'SKIP bb is not on PATH; verified protocol text only'
  (( failed )) && exit 1
  exit 0
fi

# Live CLI facts the protocol is written against.
count_help=$(bb thread count --help 2>&1)
if ! grep -q 'excludes archived and hidden threads' <<<"$count_help"; then
  printf 'FAIL bb thread count: hidden-thread exclusion changed; revisit the budget rule\n'
  failed=1
fi

if ! grep -q -- '--work-status' <<<"$(bb thread show --help 2>&1)"; then
  printf 'FAIL bb thread show: --work-status is gone; worker verification needs a new source\n'
  failed=1
fi
if ! grep -q -- '--parent-thread' <<<"$(bb thread list --help 2>&1)"; then
  printf 'FAIL bb thread list: --parent-thread is gone; nested-child wait needs a new source\n'
  failed=1
fi
if ! grep -q -- '--exit' <<<"$(bb terminal wait --help 2>&1)"; then
  printf 'FAIL bb terminal wait: --exit is gone; remote validation needs a new wait target\n'
  failed=1
fi

for subcommand in 'thread queue list' 'thread queue delete' 'thread update' \
  'thread open' 'thread list' 'thread interactions deny' 'machine list' \
  'project attachment upload' 'environment pull-request show' \
  'environment pull-request merge' 'terminal create' 'terminal wait' \
  'terminal output' 'terminal show'; do
  if ! bb $subcommand --help >/dev/null 2>&1; then
    printf 'FAIL bb %s is not a valid command\n' "$subcommand"
    failed=1
  fi
done

# gh stays authoritative for merges because the bb command cannot assert a head.
merge_help=$(bb environment pull-request merge --help 2>&1)
if grep -q -- '--match-head-commit' <<<"$merge_help"; then
  printf 'FAIL bb environment pull-request merge now asserts the head; land-stack can use it\n'
  failed=1
fi

if (( failed )); then
  exit 1
fi

echo 'PASS the worker protocol matches the installed bb CLI'
