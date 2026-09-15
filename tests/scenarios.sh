#!/usr/bin/env bash

set -uo pipefail

# Behaviour tests. Every other script in tests/ greps the skill prose; this one
# asks a fresh agent to decide under pressure and checks what it chose.
#
#   tests/scenarios.sh                  every scenario, with its skill loaded
#   tests/scenarios.sh --baseline       every scenario with NO skill loaded
#   tests/scenarios.sh serial-workers   one scenario by name
#   REPS=5 tests/scenarios.sh           five samples per scenario
#
# --baseline is the RED half of the cycle: a scenario that a skill-less agent
# already answers correctly is testing nothing, and its rule earns no words in
# the skill. Run it when you add a scenario, before you write the rule.
#
# Skipped by default: it spends real tokens. Opt in with RUN_SCENARIOS=1, which
# is what CI and `tests/run.sh --scenarios` set.

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scenario_dir="$repo_root/tests/scenarios"
reps=${REPS:-1}
model=${SCENARIO_MODEL:-}
baseline=0
selected=()

for arg in "$@"; do
  case "$arg" in
    --baseline) baseline=1 ;;
    *) selected+=("$arg") ;;
  esac
done

if [[ "${RUN_SCENARIOS:-0}" != 1 ]]; then
  echo 'SKIP scenarios need a model; set RUN_SCENARIOS=1 to spend tokens'
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo 'SKIP claude is not on PATH; cannot run scenarios'
  exit 0
fi

field() { sed -n "1,/^---$/p" "$1" | sed -n "s/^$2: //p"; }
body() { sed -n '/^---$/,$p' "$1" | tail -n +2; }

# Answer from an empty scratch directory. Run inside this repo and the agent
# picks up the very skills under test from the project's own config, which
# turns every baseline green and proves nothing.
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

ask() {
  local system=$1 prompt=$2
  local -a cmd=(claude -p --permission-mode plan --disallowed-tools 'Bash,Edit,Write,Read,WebFetch,WebSearch')
  [[ -n "$model" ]] && cmd+=(--model "$model")
  [[ -n "$system" ]] && cmd+=(--append-system-prompt "$system")
  printf '%s' "$prompt" | (cd "$scratch" && "${cmd[@]}") 2>/dev/null
}

failed=0
total=0

for scenario in "$scenario_dir"/*.md; do
  name=$(basename "$scenario" .md)
  [[ "$name" == 'README' ]] && continue
  if (( ${#selected[@]} )) && [[ ! " ${selected[*]} " == *" $name "* ]]; then
    continue
  fi

  skill_name=$(field "$scenario" skill)
  expect=$(field "$scenario" expect)
  forbid=$(field "$scenario" forbid)
  skill_file="$repo_root/skills/$skill_name/SKILL.md"

  if [[ ! -f "$skill_file" ]]; then
    printf 'FAIL %s: skill %s does not exist\n' "$name" "$skill_name"
    failed=1
    continue
  fi

  system=''
  (( baseline )) || system=$(cat "$skill_file")
  prompt=$(body "$scenario")

  complied=0
  violated=0
  unparsed=0

  for ((rep = 1; rep <= reps; rep++)); do
    answer=$(ask "$system" "$prompt")
    # Score the FIRST verdict token in the answer, not whichever we check for
    # first. An answer that picks A and then says "I considered B" contains
    # both, and checking expect first scores that violation as compliance.
    verdict=$(grep -oF -e "$expect" -e "$forbid" <<<"$answer" | head -1)
    if [[ "$verdict" == "$expect" ]]; then
      (( complied++ ))
    elif [[ "$verdict" == "$forbid" ]]; then
      (( violated++ ))
      printf '  %s rep %d rationalized: %s\n' \
        "$name" "$rep" "$(tr '\n' ' ' <<<"$answer" | tr -s ' ' | cut -c1-200)"
    else
      (( unparsed++ ))
      printf '  %s rep %d returned neither verdict: %s\n' "$name" "$rep" "$(tr '\n' ' ' <<<"$answer" | cut -c1-120)"
    fi
  done

  (( total++ ))

  if (( baseline )); then
    # RED: a scenario with no teeth cannot prove the skill did anything.
    if (( complied == reps )); then
      printf 'FAIL %s: baseline already complies %d/%d; the scenario applies no pressure\n' \
        "$name" "$complied" "$reps"
      failed=1
    else
      printf 'RED  %s: baseline complied %d/%d, violated %d, unparsed %d\n' \
        "$name" "$complied" "$reps" "$violated" "$unparsed"
    fi
  else
    # GREEN: with the skill loaded, every sample follows the rule.
    if (( complied == reps )); then
      printf 'PASS %s: %d/%d complied\n' "$name" "$complied" "$reps"
    else
      printf 'FAIL %s: complied %d/%d (violated %d, unparsed %d) with %s loaded\n' \
        "$name" "$complied" "$reps" "$violated" "$unparsed" "$skill_name"
      failed=1
    fi
  fi
done

if (( total == 0 )); then
  printf 'FAIL no scenario matched %s\n' "${selected[*]:-*}"
  exit 1
fi

if (( failed )); then
  exit 1
fi

if (( baseline )); then
  echo "PASS every scenario applies pressure a skill-less agent gives in to"
else
  echo "PASS every scenario's skill holds under pressure"
fi
