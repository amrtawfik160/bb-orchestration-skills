#!/usr/bin/env bash

set -uo pipefail

# Runs every test script and reports one line per script.
tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
failed=0

for test in "$tests_dir"/*.sh; do
  [[ "$(basename "$test")" == 'run.sh' ]] && continue
  if output=$(bash "$test" 2>&1); then
    printf '%s\n' "$output" | tail -1
  else
    printf '%s\n' "$output"
    failed=1
  fi
done

exit "$failed"
