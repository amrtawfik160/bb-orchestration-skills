#!/usr/bin/env bash

set -euo pipefail

# Behavior test: run the documented landing sequence against stubbed gh and bb.
# Asserts that PRs merge oldest first, that an environment is archived only
# after its merge is confirmed MERGED, and that a failing check stops the run
# without merging or archiving anything later in the stack.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
land="$repo_root/skills/land-stack/SKILL.md"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failed=0

fail() {
  printf 'FAIL %s\n' "$1"
  failed=1
}

# Stubs record every call in order and fail checks for the PR named in FAIL_PR.
make_stubs() {
  mkdir -p "$tmp/bin"

  cat >"$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >>"$CALLS"
case "$1 $2" in
  "pr checks")
    pr=$3
    if [[ "$pr" == "${FAIL_PR:-}" ]]; then echo "fail  build" ; exit 1; fi
    echo "pass  build"; exit 0 ;;
  "pr view")
    pr=$3
    if grep -q "^gh pr merge $pr " "$CALLS"; then
      echo '{"state":"MERGED","mergeCommit":{"oid":"deadbeef"}}'
    else
      echo '{"state":"OPEN","isDraft":false,"baseRefName":"main","headRefOid":"head-'"$pr"'","mergeable":"MERGEABLE","reviewDecision":null}'
    fi
    exit 0 ;;
  "issue view") echo '{"state":"OPEN"}'; exit 0 ;;
esac
exit 0
STUB

  cat >"$tmp/bin/bb" <<'STUB'
#!/usr/bin/env bash
echo "bb $*" >>"$CALLS"
exit 0
STUB

  chmod +x "$tmp/bin/gh" "$tmp/bin/bb"
}

# The landing sequence exactly as SKILL.md documents it, for tickets in order.
land_stack() {
  local pr env
  for i in 1 2 3; do
    pr="PR$i"; env="env$i"

    # 2. gate
    gh pr view "$pr" --json state,isDraft,baseRefName,headRefOid,mergeable >/dev/null
    if ! gh pr checks "$pr" --watch --fail-fast >/dev/null; then
      echo "paused at $pr" >>"$CALLS"
      return 0
    fi

    # 3. merge, then confirm
    gh pr ready "$pr" >/dev/null
    gh pr merge "$pr" --merge --match-head-commit "head-$pr" --delete-branch >/dev/null
    if [[ "$(gh pr view "$pr" --json state | grep -o MERGED)" != "MERGED" ]]; then
      echo "paused at $pr" >>"$CALLS"
      return 0
    fi

    # 4. close the ticket, 5. clean up only now
    gh issue view "$i" --json state >/dev/null
    gh issue close "$i" --reason completed --comment "Landed in $pr" >/dev/null
    bb environment archive-threads "$env" >/dev/null
  done
}

make_stubs
export PATH="$tmp/bin:$PATH"

# Case 1: every check green -> all three land, oldest first.
export CALLS="$tmp/calls-green"
: >"$CALLS"
unset FAIL_PR
land_stack

merges=$(grep -oE '^gh pr merge PR[0-9]' "$CALLS" | grep -oE 'PR[0-9]' | tr '\n' ' ')
[[ "$merges" == 'PR1 PR2 PR3 ' ]] || fail "green: merged out of order: $merges"

archives=$(grep -oE '^bb environment archive-threads env[0-9]' "$CALLS" | grep -oE 'env[0-9]' | tr '\n' ' ')
[[ "$archives" == 'env1 env2 env3 ' ]] || fail "green: archived out of order: $archives"

closed=$(grep -cE '^gh issue close' "$CALLS")
[[ "$closed" == 3 ]] || fail "green: expected 3 issues closed, got $closed"

# Every archive must come after its own merge confirmation.
for i in 1 2 3; do
  merge_line=$(grep -n "^gh pr merge PR$i " "$CALLS" | head -1 | cut -d: -f1)
  archive_line=$(grep -n "^bb environment archive-threads env$i" "$CALLS" | head -1 | cut -d: -f1)
  if [[ -z "$merge_line" || -z "$archive_line" ]] || (( archive_line < merge_line )); then
    fail "green: env$i archived before PR$i merged"
  fi
done

# Case 2: PR2 checks fail -> PR1 lands, PR2 and PR3 do not, nothing later is archived.
export CALLS="$tmp/calls-fail"
: >"$CALLS"
export FAIL_PR=PR2
land_stack

grep -q '^gh pr merge PR1 ' "$CALLS" || fail 'failing check: PR1 should still have merged'
grep -q '^bb environment archive-threads env1' "$CALLS" || fail 'failing check: env1 should still be archived'
grep -q 'paused at PR2' "$CALLS" || fail 'failing check: run should pause at PR2'

for pr in PR2 PR3; do
  if grep -q "^gh pr merge $pr " "$CALLS"; then fail "failing check: $pr must not merge"; fi
done
for env in env2 env3; do
  if grep -q "^bb environment archive-threads $env" "$CALLS"; then
    fail "failing check: $env must not be archived"
  fi
done

# The documented command strings must match what this test ran.
for cmd in \
  'gh pr checks "\$URL" --watch --fail-fast' \
  'gh pr ready "\$URL"' \
  '--match-head-commit' \
  '--delete-branch' \
  'gh issue close <n> --reason completed' \
  'bb environment archive-threads "\$ENV"'
do
  grep -q -- "$cmd" "$land" || fail "land-stack SKILL.md: command drifted from the tested procedure: $cmd"
done

if (( failed )); then
  exit 1
fi

echo 'PASS landing merges oldest first and archives only after a confirmed merge'
