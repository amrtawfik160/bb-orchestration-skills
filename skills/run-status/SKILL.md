---
name: run-status
description: "Print a one-pane status of a BB orchestration run from its ledger: tickets, PRs, checks, child threads, and blockers. Use when asked where a run stands."
argument-hint: "[ledger path]"
---

# Run Status

Answer "where does the run stand" from the ledger, the child threads, and
the PRs. Read-only and single-turn: queue no continuation, spawn nothing,
and write nothing.

## Contract

- Read the ledger, never write it. Spawning workers and mutating `gh` or
  `git` commands are out of scope; `bb thread tell` is never sent.
- Resolve one ledger: the attached path, else
  `$BB_THREAD_STORAGE/orchestrate-implementation/run.json`, else
  `$BB_THREAD_STORAGE/review-fix-loop/<base7>.json`, else ask.
- Report children with `bb thread count` and `bb thread list`, and PR checks
  with read-only `gh pr checks` and `gh pr view`. Take no action on what
  they show.
- Render in `references/format.md` and stop.

## References

`references/format.md` owns the output sections and field mapping.

## Report

1. Read the ledger and map every field the format needs; reconcile thread
   states with `bb thread show` and PR states with `gh pr view` before
   printing.
2. Print the format's sections in order, with ledger path, thread IDs, and PR
   URLs as pointers. Name the pause, the quarantine, and the red-main
   response when one is present; a missing gate verdict is a finding.
3. Stop. A stale or contradictory record is reported, never repaired.
