# Quarantine and reopen budget

Validation failures split three ways: a real regression the fix caused, a
flake that would fail on any head, and a finding that keeps returning. The
first gets fixed, the second gets quarantined, the third pauses. None of
them loops forever.

## Attempt evidence

After every fix, the orchestrator runs `validation` itself and appends one
`attempts[]` entry: the fix head, the validation result, and the failing
checks. Attempts are evidence, not a counter: converging work is never cut
off by a number.

## Flake patterns

Quarantine when either pattern proves the failure is not the fix:

- Re-run green: the same check is red, then green on an immediate re-run
  with no code change between.
- Alternating: the same check alternates red, green, red across three
  consecutive fix commits.

## Quarantine

1. Record `quarantine[]` with the check name, the pattern, the evidence, and
   the ticket.
2. File the repair as a `ready-for-agent` ticket labeled `flaky`, with the
   evidence and the re-run pair or the three alternating heads.
3. Notify the user in one line: what flaked, its ticket, and that gating
   continues without it.
4. Exclude the quarantined check from gating only with its ticket recorded:
   a quarantine without a ticket is a skipped check.

Unquarantine only on human ack or when the repair ticket lands; then
re-measure before trusting the check again.

## Reopen budget

A stable finding ID that returns RESOLVED to OPEN twice is cycling, not
converging: pause with `class: decision`, attaching the diagnosis bundle
(attempts, fix diffs, validation logs, and the closure evidence that
reopened it). This caps cycling; `best-burden` still has no attempt counter,
and converging work still runs to zero under the worker budget.

## Baseline versus quarantine

`ci_baseline` names failures already red when the run started; quarantine
names failures proven flaky mid-run. Gates treat both as inherited: the land
and verify gates merge and prove through either, reporting each with its
baseline entry or quarantine ticket.
