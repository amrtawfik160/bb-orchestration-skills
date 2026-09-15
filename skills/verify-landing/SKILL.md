---
name: verify-landing
description: "Verify each landed merge commit on the target branch: green checks and smoke validation per merge, with a revert-first response when the target goes red. Use after land-stack merges a stack, or when asked to prove the target is green."
argument-hint: "[run ledger path] | resume"
---

# Verify Landing

Take a `land-stack` run from "every PR is merged" to "every merge is
proven green on the target". Each merge verifies oldest first in its own
visible BB thread sharing one verify worktree at the target head.

## Contract

- Verify oldest first. A merge is proven only when its merge-commit checks
  are green net of `ci_baseline` and quarantine, and smoke validation passes.
- Give every merge a fresh visible BB thread in one verify environment.
  Never fork or reuse a worker.
- A red target gets a response, never silence. Follow
  `references/red-main.md`: fix forward only when the cause is known and one
  ticket heals it, else revert first and file the fix.
- Work from the ledger: read `run.json`, write every transition.
- A run outlives one turn. End a turn only in a terminal state or with the
  skill's `[continuation]` template queued per `bb-workers.md`.

## References

Follow `../bb-worker-protocol/references/bb-workers.md` for spawning, waiting,
interactions, verification, budgets, pausing, continuation, notification,
auto-resume, and its GitHub section; prefer the `gh-axi` skill over raw `gh`,
reading current syntax from the CLI. The `gh` commands below define what must
be true, not which binary runs it. The ledger schema is
`../bb-worker-protocol/references/run-ledger.md`; verification fills
`tickets.<id>.verification` and the top-level `verification` object.

## Prepare

1. Read the run ledger: the attached path, else
   `$BB_THREAD_STORAGE/orchestrate-implementation/run.json`. Require
   `state: landed`, or `verification` already present for `resume`. Reconcile
   every merge with `gh pr view` before the first transition.
2. Resolve `smoke`: the ticket's own smoke line, else the project's documented
   smoke check, else the fastest validation subset that proves the target
   boots and the landed behavior holds. Record the command.
3. Create one managed worktree at the target head and record `verification`
   in the ledger.

## Verify one merge

For the oldest unverified ticket in `order`:

1. Spawn a verify worker:

```text
Verify merge <sha> on <target>: merge-commit checks plus <smoke command>.
Report check conclusions, smoke output, and failure evidence.
Keep the worktree unchanged.
```

2. The worker proves:

   ```bash
   gh api repos/{owner}/{repo}/commits/<merge-sha>/check-runs --jq '.check_runs[] | "\(.name): \(.conclusion)"'
   <smoke command>
   ```

   Require no failing check outside the run's `ci_baseline` and quarantine,
   and a green smoke run. A failure named in either is inherited or flaky:
   report it with its baseline entry or quarantine ticket and continue.
3. Write `tickets.<id>.verification`, then continue with the next merge.

## Red target

A failing check the merge caused, or a red smoke run, pauses this merge and
follows `references/red-main.md` before any later merge verifies: the stack
stays ordered, and one red merge blocks the proof of the rest.

## Pause

A failing gate, a missing merge commit, or a red-main response in flight
pauses verification. Proven merges stay proven; `resume` reconciles the
ledger and starts at the first unverified ticket.

## Finish

Report each merge with its commit, checks, smoke result, and verification
state. End with:

```yaml
VERIFY_GATE:
  verdict: VERIFIED | PAUSED
  merge_commits: <count>
  proven: <count>
  open_response_tickets: <count>
```

Set `verification.state: verified` in the ledger.
