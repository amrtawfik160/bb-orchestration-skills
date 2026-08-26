#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
failed=0

require_text() {
  local file=$1
  local expected=$2
  local normalized

  normalized=$(tr '\n' ' ' <"$file" | tr -s '[:space:]' ' ')
  if [[ $normalized != *"$expected"* ]]; then
    printf 'FAIL %s: missing %s\n' "${file#"$repo_root"/}" "$expected"
    failed=1
  fi
}

reject_text() {
  local file=$1
  local rejected=$2
  local normalized

  normalized=$(tr '\n' ' ' <"$file" | tr -s '[:space:]' ' ')
  if [[ $normalized == *"$rejected"* ]]; then
    printf 'FAIL %s: contains obsolete policy %s\n' "${file#"$repo_root"/}" "$rejected"
    failed=1
  fi
}

check_prompt_size() {
  local file=$1
  local block_lines

  while read -r block_lines; do
    if (( block_lines > 4 )); then
      printf 'FAIL %s: worker prompt has %s lines\n' \
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
  require_text "$skill" 'At most three review attempts'
  require_text "$skill" 'two consecutive reviews do not reduce'
  require_text "$skill" 'root cause repeats'
  require_text "$skill" 'one fresh diagnosis worker'
  require_text "$skill" 'FOLLOW_UP'
  require_text "$skill" 'A dirty run environment pauses'
  require_text "$skill" 'BB pins skill revisions per environment'
  require_text "$skill" 'Attach sources; never paste their contents or restate a skill'
  require_text "$skill" '/code-review <base> <spec>'
  require_text "$skill" 'Work alone; run Standards then Spec sequentially; create no descendants.'
  reject_text "$skill" 'Repeat until `0`, `0`, `0`, `PASS`'
  reject_text "$skill" 'never waive them or impose a retry limit'
  check_prompt_size "$skill"

  lines=$(wc -l <"$skill")
  if (( lines > 150 )); then
    printf 'FAIL %s: %s lines exceeds compactness budget\n' \
      "${skill#"$repo_root"/}" "$lines"
    failed=1
  fi
done

require_text "$repo_root/skills/orchestrate-implementation/SKILL.md" '/implement <unit>'
require_text "$repo_root/skills/orchestrate-implementation/SKILL.md" 'Stop before its built-in review.'
require_text "$repo_root/skills/review-fix-loop/SKILL.md" '/implement'
require_text "$repo_root/skills/review-fix-loop/SKILL.md" 'Fix the attached findings with `/tdd` where useful.'

if (( failed )); then
  exit 1
fi

echo 'PASS review loops are bounded and worker prompts are compact'
