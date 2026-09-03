#!/usr/bin/env bash

set -euo pipefail

# Drift guard: every bb flag used in the worker protocol must exist in the
# installed bb CLI's --help output. Skips when bb is not on PATH.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
protocol="$repo_root/skills/review-fix-loop/references/bb-workers.md"
failed=0

if ! command -v bb >/dev/null 2>&1; then
  echo 'SKIP bb is not on PATH; cannot verify worker protocol flags'
  exit 0
fi

check_flags() {
  local subcommand=$1
  local help
  help=$(bb $subcommand --help 2>&1) || { printf 'FAIL bb %s --help failed\n' "$subcommand"; failed=1; return; }

  while read -r flag; do
    [[ -z "$flag" ]] && continue
    if ! grep -q -- "$flag" <<<"$help"; then
      printf 'FAIL bb %s: flag %s is not in --help\n' "$subcommand" "$flag"
      failed=1
    fi
  done < <(
    grep -E "^\s*bb $subcommand( |$)|^\s*--" "$protocol" \
      | awk -v cmd="bb $subcommand" '
          index($0, cmd) { on = 1 }
          on { print; if ($0 !~ /\\$/) on = 0 }
        ' \
      | grep -oE -- '--[a-z-]+' | sort -u
  )
}

check_flags 'thread spawn'
check_flags 'thread wait'
check_flags 'thread show'
check_flags 'thread log'
check_flags 'thread interactions answer'
check_flags 'thread output'
check_flags 'environment status'

for subcommand in 'thread tell' 'thread retry' 'thread interactions list' \
  'thread interactions show' 'thread interactions approve' 'environment show' \
  'provider list' 'provider models'; do
  if ! bb $subcommand --help >/dev/null 2>&1; then
    printf 'FAIL bb %s is not a valid command\n' "$subcommand"
    failed=1
  fi
done

if (( failed )); then
  exit 1
fi

echo 'PASS worker protocol commands and flags exist in the installed bb CLI'
