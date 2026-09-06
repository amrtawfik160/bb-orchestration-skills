#!/usr/bin/env bash

set -euo pipefail

# Drift guard: the worker protocol relies on documented bb behaviour, not just
# on flags existing. Each check below pins one fact the protocol depends on, so
# a bb release that changes the fact fails here instead of in a live run.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
protocol="$repo_root/skills/review-fix-loop/references/bb-workers.md"
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

# Progress detection pages forward from the last seen sequence. A JSON limit
# returns the oldest events, so every window would compare the same opening
# events and read as no progress.
require_pattern "$protocol" 'bb thread log "\$WORKER" --format json --after-seq'
require_pattern "$protocol" 'last_seq'
reject_pattern "$protocol" '^\s*bb thread log .*--format json --limit' \
  'pages the oldest events and never shows progress'

# A worker can be held rather than stalled, and a retry can already be queued.
require_pattern "$protocol" 'bb thread queue list'
require_pattern "$protocol" 'waitingOn'
require_pattern "$protocol" 'retry_already_queued'

# Both permission ceilings, and attachments that must exist on the worker's host.
require_pattern "$protocol" 'maxPermissionMode'
require_pattern "$protocol" 'bb project attachment upload'

# Hidden workers are unreachable from the sidebar and uncountable.
require_pattern "$protocol" 'bb thread update "\$WORKER" --visibility visible'
require_pattern "$protocol" 'bb thread open "\$WORKER"'
require_pattern "$protocol" 'exclude\s+hidden threads'

# The single-shot resume needs no cleanup; the automation remains the fallback.
require_pattern "$protocol" '--send-at 15m'
require_pattern "$protocol" 'bb thread queue delete'

if ! command -v bb >/dev/null 2>&1; then
  echo 'SKIP bb is not on PATH; verified protocol text only'
  (( failed )) && exit 1
  exit 0
fi

# Live CLI facts the protocol is written against.
log_help=$(bb thread log --help 2>&1)
if ! grep -q -- '--after-seq' <<<"$log_help"; then
  printf 'FAIL bb thread log: --after-seq is gone; progress paging needs a new source\n'
  failed=1
fi
if ! grep -q 'oldest first' <<<"$log_help"; then
  printf 'FAIL bb thread log: json limits are no longer oldest-first; revisit the paging rule\n'
  failed=1
fi

count_help=$(bb thread count --help 2>&1)
if ! grep -q 'excludes archived and hidden threads' <<<"$count_help"; then
  printf 'FAIL bb thread count: hidden-thread exclusion changed; revisit the budget rule\n'
  failed=1
fi

for subcommand in 'thread queue list' 'thread queue delete' 'thread update' \
  'thread open' 'thread interactions deny' 'machine list' \
  'project attachment upload' 'environment pull-request show' \
  'environment pull-request merge' 'terminal create' 'terminal wait' \
  'terminal output'; do
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
