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

  # Every backticked relative reference path must exist. Resolve it from the
  # directory of the file that wrote it, not from the skill root: a reference
  # linking to another reference is one ../ shallower, and checking only
  # SKILL.md let two broken links through a whole refactor.
  while read -r src ref; do
    [[ -z "$ref" ]] && continue
    if [[ ! -f "$(dirname "$src")/$ref" ]]; then
      fail "${src#"$repo_root"/}: referenced file '$ref' does not exist"
    fi
  done < <(
    grep -rhoE --include='*.md' -H '`(\.\./)*[a-z0-9-]*/?references/[a-z0-9-]+\.md`' "$skill_dir" \
      | tr -d '`' | tr ':' ' ' | sort -u
  )

  if ! grep -q "\"$name\"" "$repo_root/skills.sh.json"; then
    fail "skills.sh.json: does not list $name"
  fi
done

# JSON examples inside reference files must parse.
for ref in "$repo_root"/skills/*/references/ledger.md \
           "$repo_root"/skills/bb-worker-protocol/references/run-ledger.md; do
  if ! awk '/^```json$/ {on=1; next} /^```$/ {on=0} on' "$ref" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    fail "${ref#"$repo_root"/}: JSON example does not parse"
  fi
done

# Dependencies point down, never sideways. Anything more than one skill needs
# belongs in bb-worker-protocol; reaching into a peer's references/ breaks the
# moment that peer is installed on its own.
while read -r offender; do
  [[ -z "$offender" ]] && continue
  fail "$offender: reaches into a peer skill's references/; move the shared file to bb-worker-protocol"
done < <(
  grep -rnoE '\.\./(\.\./)?[a-z-]+/references/' "$repo_root"/skills --include='*.md' \
    | grep -v '/bb-worker-protocol/references/' \
    | cut -d: -f1-2
)

# Every scenario names a real skill and both verdicts.
for scenario in "$repo_root"/tests/scenarios/*.md; do
  [[ "$(basename "$scenario")" == 'README.md' ]] && continue
  rel="${scenario#"$repo_root"/}"
  skill_name=$(sed -n '1,/^---$/p' "$scenario" | sed -n 's/^skill: //p')
  [[ -f "$repo_root/skills/$skill_name/SKILL.md" ]] \
    || fail "$rel: names skill '$skill_name', which does not exist"
  for key in expect forbid; do
    sed -n '1,/^---$/p' "$scenario" | grep -q "^$key: " \
      || fail "$rel: missing '$key:' in its header"
  done
done

if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$repo_root/skills.sh.json" 2>/dev/null; then
  fail "skills.sh.json does not parse"
fi

# Single source of truth. Each rule below belongs to one file; a second copy is
# a two-place edit waiting to drift, and it inflates the rule's rank by making
# it look like a skill's own contract rather than the runtime's.
while read -r rule; do
  [[ -z "$rule" ]] && continue
  hits=0
  while read -r f; do
    awk '/^[[:space:]]*```/ {fenced = !fenced; next} !fenced' "$f" \
      | tr '\n' ' ' | tr -s ' ' | grep -qiF -- "$rule" && (( ++hits ))
  done < <(find "$repo_root"/skills -name '*.md')
  if (( hits > 1 )); then
    fail "'$rule' appears in $hits files; bb-worker-protocol owns it"
  elif (( hits == 0 )); then
    fail "'$rule' appears nowhere; bb-worker-protocol should still own it"
  fi
done <<'RULES'
A run outlives one turn
End with the attached WORKER_RESULT footer.
Prefer the `gh-axi` skill over raw `gh`
Never fork or reuse a worker
RULES

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
