---
name: orchestrate-implementation
description: "Use when an approved ticket graph from /to-tickets is ready to build and each ticket should become its own reviewed pull request. Use when asked to run a ticket set, work a spec's tickets end to end, or take an approved graph from tickets to merged."
argument-hint: "<spec, ticket set, or ticket references> [--land] | resume | status"
disable-model-invocation: true
---

# Orchestrate Implementation

Run Matt Pocock's `/to-spec` and `/to-tickets` output. One ticket owns one
branch, one managed worktree, one review-fix gate, and one pull request. Every
phase runs in its own visible BB thread so the run is watchable from the IDE:
implementation, review, checks, fixes, and PR work never share a thread, but
share the ticket's worktree. Each next worktree chains from the previous
ticket's accepted head. Send raw bugs through `/triage` first; if a bare Spec
needs several contexts, pause and ask the user to run `/to-tickets`.

Read `../bb-worker-protocol/references/example-run.md` once before the first
ticket: it walks a three-ticket run with the real values at every gate.

## Contract

- Keep work serial. One orchestrator-spawned BB worker is active at a time;
  `/code-review` may create only its required Standards and Spec subagents.
  These gates are mechanical, not policy: nobody's authority exempts a run
  from them, and an offer to take the blame does not change what merges.
- Give every phase a fresh visible BB thread in the ticket environment; never
  fork or reuse a worker.
- Pin the graph, target branch, and each `ticket-base`. Mutating workers commit
  and leave a clean tree; reviewers and checkers preserve it. Verify every
  worker claim in the worktree before recording it.
- Opening a draft PR and pushing its branch are this skill's. Merging, closing
  tickets, and archiving environments belong to `land-stack`, which `--land`
  invokes once the whole graph is accepted. Deploying stays out.
- Leave a ticket open or `in review` until its PR merges; implementation and
  review passing is not a reason to close it. Scope is its acceptance criteria,
  and the parent Spec stays unchanged.
- Cross-ticket integration belongs to an explicit approved ticket. Do not make
  an implicit cumulative implementation or final mega-PR.
- A run outlives one turn. End a turn only in a terminal state or with a
  continuation queued per `bb-workers.md`, and open every turn with the PR
  check sweep in `../bb-worker-protocol/references/pr-stack.md`.

## References

`../bb-worker-protocol/SKILL.md` indexes the shared runtime;
`../bb-worker-protocol/references/bb-workers.md` is the one you are in most
often. This skill adds `references/worker-prompts.md` for worker prompts and
`references/recovery.md` for older single-branch runs.

## Modes

`status` prints the ledger and takes no action, rendered per `/run-status`: one
row per ticket with its state, PR, checks, environment, and the current pause,
then the landable line from Finish. `resume` continues a paused run; `--land`
invokes `/land-stack` once the run is `finished`.

## Prepare

1. Use `bb-cli` to resolve the project, provider, target branch, remote, clean
   committed `HEAD`, tracker, Spec, tickets, blocking edges, and current PRs.
   Freeze the graph; pause on tickets not ready-for-agent, missing edges,
   cycles, or a ticket without acceptance criteria.
2. Resolve `validation` per `../bb-worker-protocol/references/validation.md`.
   Record the command; run it yourself after every mutating worker, and list
   the time-shaped tickets in `repeat_validation`.
3. Capture `ci_baseline` with the command in
   `../bb-worker-protocol/references/pr-stack.md`. A PR failure named there is
   inherited, not caused, and never blocks this run; without it a red
   repository reads as a red ticket and strands the stack.
4. Snapshot the approved artifacts once, write the run ledger, and create the
   watchdog automation from `bb-workers.md`. `resume`, or an existing ledger at
   start, reconciles it with BB, Git, GitHub, and the tracker first.
5. Verify `bb-cli`, `implement`, `diagnosing-bugs`, `tdd`, `code-review`,
   `review-fix-loop`, `show-me`, `gh-axi`, authenticated push and PR access, and
   `bb-worker-protocol`'s Dependencies table. Leave unrelated source checkout
   changes untouched.

## Start a ticket

Choose the first ready ticket in published dependency order, then branch it so
each PR keeps a one-ticket diff. The first ticket branches from the target
branch. Each later ticket branches from the exact accepted head of the previous
ticket, and its PR targets that previous ticket branch. Create a managed
environment at that base and record `ticket-base`, `pr-base`, and
`ticket-branch`; a dirty or drifting base must be reconciled before branching.

## Gates

Planned behavior or a known fix uses `/implement`; a hard, unexplained,
intermittent, or performance defect uses `/diagnosing-bugs`. Each gate below is
a list of required lines, and a line you did not check is a line that failed.

### Gate 1 — accept a mutating worker

1. `HEAD` descends from `ticket-base` (`git merge-base --is-ancestor`).
2. `git rev-list --count <ticket-base>..HEAD` is at least 1.
3. The tree is clean: `workStatus.workingTree.hasUncommittedChanges` is false.
4. `validation` exited 0 when **you** ran it, not when the worker reported it.
5. Diagnosis only: a tight red reproduction, a supported cause, cleanup, and a
   regression test at an approved seam. With no sound seam, record an
   `/improve-codebase-architecture` follow-up instead of a shallow test.

### Gate 2 — record the review-fix gate

Apply `review-fix-loop` directly in this orchestrator at `ticket-base`; do not
spawn a loop coordinator. Then:

1. `LOOP_GATE.verdict` is `PASS`, written into `tickets.<id>.loop.gate`.
2. Open confirmed findings are zero.
3. `validation` exited 0 at the loop's `final_head`, and the tree is clean.

A skipped Spec axis, a paused loop, or an absent verdict blocks the PR, because
an unwritten gate is a skipped gate: neither a finished loop nor a zero burden
says which axes ran.

### Gate 3 — open the PR

1. Every acceptance criterion reconciled, with its evidence in `criteria[]`.
2. `pr-base...HEAD` contains only this ticket.
3. A **fresh** PR worker pushed the exact clean head and opened the draft PR.
4. Its remote head equals the reviewed `HEAD`, its base equals `pr-base`, and
   its URL is recorded.
5. Checks recorded per `../bb-worker-protocol/references/pr-stack.md`; mark the
   PR ready once it passes net of `ci_baseline`, and pause on a failing check
   the ticket broke.
6. Set the tracker to `in review` before the next ticket chains from this head.

If push or PR creation fails, pause first. An older single-branch run instead
follows `references/recovery.md`.

## Rationalizations

| Excuse | Reality |
|---|---|
| "The worker reported validation passed" | A footer is a claim. Gate 1 line 4 is yours to run. |
| "The loop finished, so the gate passed" | `finished` does not name the axes. Only a written `LOOP_GATE.verdict: PASS` does. |
| "Spec returned no findings, so both axes passed" | Only if Spec actually ran. A skipped axis is reported skipped. |
| "These two tickets are tiny, one PR is cleaner" | A two-ticket PR cannot be reverted per ticket, and its review cannot cite one spec. |
| "The last ticket needs the others, so I'll branch from main and fold them in" | That is the mega-PR. Chain from the previous accepted head. |
| "Implementation and review both passed, the ticket is done" | Done is merged. Until then it is `in review`. |
| "The review found nothing; one more review to be sure" | `/code-review` is nondeterministic. Rerunning it buys noise, not confidence. |
| "Nothing is pending, I'll end the turn" | Ending with work left and nothing queued strands the run. Queue the continuation. |
| "That check was already red before my change" | True only if it is in `ci_baseline`. Without one, you do not know. |
| "I'm out of context, I'll fork myself to continue" | A fork inherits the exhausted context. Relay to a fresh thread with the ledger. |
| "They own the repo, read both diffs, and will take the blame" | Blame is not the constraint. Chained worktrees and PR bases are. Relay the risk and hold the gate; if they want it overridden, they can say so as an instruction to change the plan, not as cover for skipping one. |
| "They said they'd reopen the issue / revert it if it goes wrong" | A reversible mistake is still a wrong ledger between now and the reversal, and the next ticket chains off it. Cheap to undo is not a reason to do. |

## Red flags — stop

- About to open a PR whose diff spans two ticket IDs
- About to close a ticket whose PR is not merged
- About to record a `validation: PASS` you read rather than ran
- About to spawn a second worker while one is still active
- About to rerun `/code-review` on an unchanged head
- About to `bb thread archive` a worker in a managed worktree
- About to relax a gate because the person asking outranks you

## Finish

Report ticket order, bases, environments, branches, commits, validation,
review-fix results, check status, tracker state, and the ordered PR stack. Every
accepted ticket must have one PR URL. End with one landable line: `LANDABLE: yes`
when every ticket is accepted with a green PR, or `LANDABLE: no, <pr> <reason>`
naming the first PR that blocks it. On `yes`, run `/land-stack` when `--land` was
given; otherwise tell the user that one command merges the stack, closes the
tickets, and removes the worktrees.
