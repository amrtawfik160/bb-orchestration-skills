#!/usr/bin/env bash

set -euo pipefail

# Structural checks: frontmatter, referenced files exist, JSON examples parse,
# and skills.sh.json lists every bundled skill.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
failed=0

fail() {
  printf 'FAIL %s\n' "$1"
  failed=1
}

for skill_dir in "$repo_root"/skills/*/; do
  name=$(basename "$skill_dir")
  skill="$skill_dir/SKILL.md"

  [[ -f "$skill" ]] || { fail "skills/$name: missing SKILL.md"; continue; }

  if [[ "$(head -1 "$skill")" != '---' ]]; then
    fail "skills/$name/SKILL.md: frontmatter must start with ---"
  fi

  frontmatter_name=$(awk 'NR>1 && /^---$/ {exit} /^name:/ {sub(/^name:[[:space:]]*/, ""); print}' "$skill")
  if [[ "$frontmatter_name" != "$name" ]]; then
    fail "skills/$name/SKILL.md: frontmatter name '$frontmatter_name' does not match directory"
  fi

  if ! awk 'NR>1 && /^---$/ {exit} /^description:/ {found=1} END {exit !found}' "$skill"; then
    fail "skills/$name/SKILL.md: missing description"
  fi

  # Every backticked relative reference path must exist.
  while read -r ref; do
    [[ -z "$ref" ]] && continue
    if [[ ! -f "$skill_dir/$ref" ]]; then
      fail "skills/$name/SKILL.md: referenced file '$ref' does not exist"
    fi
  done < <(grep -oE '`(\.\./[a-z-]+/)?references/[a-z-]+\.md`' "$skill" | tr -d '`' | sort -u)

  if ! grep -q "\"$name\"" "$repo_root/skills.sh.json"; then
    fail "skills.sh.json: does not list $name"
  fi
done

# JSON examples inside reference files must parse.
for ref in "$repo_root"/skills/*/references/ledger.md; do
  if ! awk '/^```json$/ {on=1; next} /^```$/ {on=0} on' "$ref" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    fail "${ref#"$repo_root"/}: JSON example does not parse"
  fi
done

if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$repo_root/skills.sh.json" 2>/dev/null; then
  fail "skills.sh.json does not parse"
fi

# The vendored show-me skill keeps its license beside it.
[[ -f "$repo_root/skills/show-me/LICENSE" ]] || fail "skills/show-me/LICENSE is missing"

# show-me is vendored for BB: open HTML in the thread, not Claude Code's Bash open.
show_me="$repo_root/skills/show-me/SKILL.md"
if grep -q 'Bash(open' "$show_me"; then
  fail "skills/show-me/SKILL.md: still uses Claude Code Bash(open)"
fi
if ! grep -q 'bb thread open' "$show_me"; then
  fail "skills/show-me/SKILL.md: must open HTML with bb thread open"
fi
if ! grep -q 'inline-vis' "$show_me"; then
  fail "skills/show-me/SKILL.md: must emit the inline-vis directive"
fi

if (( failed )); then
  exit 1
fi

echo 'PASS skill frontmatter, references, JSON examples, and registry entries are consistent'
