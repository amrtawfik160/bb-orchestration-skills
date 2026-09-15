# Validation

Every skill in this bundle resolves one `validation` command in Prepare,
records it in the ledger, and runs it itself. A worker's `validation: PASS`
is a claim; the orchestrator's exit 0 is the evidence.

## Resolve

Take the first that exists:

1. The ticket's own validation line.
2. The project's documented check (its instructions file, `CONTRIBUTING`, CI).
3. The package's `test`, `lint`, and `typecheck` scripts, composed.

Record the exact string. A command you resolved but never ran is not a
validation command; run it once at the pinned base before the first worker so
a pre-existing failure is a baseline, not a verdict on someone's diff.

## Baseline

Record what already fails at the base, plus any dependency that could not run.
A failure in the baseline is never evidence against a later batch, fix, or
ticket. Report it; do not repair it inside a ticket that did not cause it.

This is the local twin of `run-ledger.md`'s `ci_baseline`, which does the same
job for hosted checks.

## Run it yourself

Run `validation` after every mutating worker, before recording that worker's
result. Never record a validation you did not watch exit 0 — including one a
worker reports in a footer, and including one on another machine, where the
exit code lives on the terminal session record (see `bb-workers.md`).

A read-only worker runs no validation. Verify instead that it left `HEAD` and
the tree exactly as it found them.

## Repeat when the diff is time-shaped

Rerun the affected suite when the diff touches time, clocks, concurrency,
ordering, or randomness. One green run cannot tell a passing test from a flaky
one, and every later ticket stacked on a flaky head inherits the repair.
Record those tickets in `repeat_validation`.

## Per-skill additions

| Skill | Adds |
|---|---|
| `orchestrate-implementation` | Runs it after every mutating worker and again before the PR opens |
| `review-fix-loop` | Runs it after every fix, logging each attempt per its `quarantine.md` |
| `codebase-docs-cleanup` | Runs it once at `cleanup-base` for the baseline, then after every batch; a new failure reverts that batch |
| `verify-landing` | Uses `smoke`, not `validation`: the fastest subset that proves the target boots and the landed behavior holds |
