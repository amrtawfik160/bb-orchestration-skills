# Red-main response

A merge that turns the target red gets a response before any later merge
verifies. Silence is the only forbidden move: every red target ends with a
revert PR, a fix ticket, or both, plus a user notification.

## Classify

- A failure named in `ci_baseline` is inherited, not caused: report it and
  continue. A failure matching a quarantined entry is flaky: report it with
  its quarantine ticket and continue. Neither is a red target.
- Anything else the merge caused, or a red smoke run, is a red target.

## Fix forward or revert first

Fix forward only when all three hold: the root cause is identified in this
turn, one owner heals it in one ticket, and the target re-greens within one
cycle. Otherwise revert first.

Revert first:

1. Spawn a fresh visible BB thread that reverts the merge commit in a managed
   worktree at the target head and opens a revert PR against the target.
2. The revert PR merges only through the `land-stack` gate: green checks and
   a head that still matches the reviewed one.
3. File the real fix as a `ready-for-agent` ticket with the failure evidence,
   and link the revert PR, the fix ticket, and the failing run in all three.

Fix forward:

1. File the fix as a `ready-for-agent` ticket owned by the cause, with the
   failure evidence and the merge commit it heals.
2. Track it to green on the target; if it slips past one cycle, revert first
   instead.

## Record

Write `tickets.<id>.verification.response` with the path taken, the revert PR
or fix ticket, and the evidence. Notify the user in one line per
`bb-workers.md`: what went red, which path, and where to watch.
