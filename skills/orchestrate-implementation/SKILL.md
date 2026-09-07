---
name: orchestrate-implementation
description: "Run an approved ticket graph serially in fresh BB threads: one reviewed pull request per ticket, and with --land, merge the stack."
argument-hint: "<spec, ticket set, or ticket references> [--land] | resume | status"
disable-model-invocation: true
---

# Orchestrate Implementation

Run Matt Pocock's `/to-spec` and `/to-tickets` output. One ticket owns one
branch, one BB environment, one review-fix gate, and one pull request.

Send raw bugs through `/triage` first. If a bare Spec needs several contexts,
pause and ask the user to run `/to-tickets`.

## Contract

- Keep work serial. One orchestrator worker is active at a time; `/code-review`
  may create only its required Standards and Spec subagents.
- Use a fresh thread for implementation, diagnosis, each review-fix phase, and
  PR writing, and apply `review-fix-loop` here so it spawns only those phase
  workers. One ticket shares one environment; the next gets a new branch and
  environment. Spawn, never fork.
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
  check sweep in `references/pr-stack.md`.

## References

Follow `../review-fix-loop/references/bb-workers.md` for spawning, waiting,
interactions, verification, budgets, continuation, relay, pausing, notification,
and auto-resume, and attach `../review-fix-loop/references/worker-footer.md` to
every worker. Keep the ledger in `references/ledger.md`. After a PR opens,
`references/pr-stack.md` owns the baseline, checks, ready state, merges,
rebases, and review comments. `references/worker-prompts.md` holds the
implementation, diagnosis, and pull request prompts.

## Modes

`status` prints the ledger and takes no action: one row per ticket with its
state, PR, checks, environment, and the current pause, then the landable line
from Finish. `resume` continues a paused run. `--land` invokes `/land-stack`
once the run is `finished`, so one invocation goes from tickets to merged.

## Prepare

1. Use `bb-cli` to resolve the project, provider, target branch, remote, clean
   committed `HEAD`, tracker, Spec, tickets, blocking edges, and current PRs.
   Freeze the graph; pause on tickets not ready-for-agent, missing edges, cycles, or a
   ticket without acceptance criteria.
2. Resolve `validation`: the ticket's own validation line, else the project's
   documented check, else the package's `test`, `lint`, and `typecheck`
   scripts. Record the command; run it yourself after every mutating worker.
   Repeat the affected suite when a diff touches time, clocks, concurrency,
   ordering, or randomness: one green run cannot tell a passing test from a
   flaky one, and every PR stacked on a flaky head inherits the repair.
3. Capture `ci_baseline` with the command in `references/pr-stack.md`. A PR
   failure named there is inherited, not caused, and never blocks this run;
   without it a red repository reads as a red ticket and strands the stack.
4. Snapshot the approved artifacts once and write the run ledger. `resume`, or
   an existing ledger at start, reconciles it with BB, Git, GitHub, and the
   tracker before one next transition.
5. Verify `bb-cli`, `implement`, `diagnosing-bugs`, `tdd`, `code-review`,
   `review-fix-loop`, `show-me`, `gh-axi`, and authenticated push and PR access.
   Leave unrelated source checkout changes untouched.

## Start a ticket

Choose the first ready ticket in published dependency order, then branch it so
each PR keeps a one-ticket diff. The first ticket branches from the target
branch. Each later ticket branches from the exact accepted head of the previous
ticket, and its PR targets that previous ticket branch. Create a managed
environment at that base and record `ticket-base`, `pr-base`, and
`ticket-branch`. A dirty or drifting base pauses the run.

## Gates

Planned behavior or a known fix uses `/implement`; a hard, unexplained,
intermittent, or performance defect uses `/diagnosing-bugs`. Implementation
must advance from `ticket-base`, pass required validation, and leave a clean
tree. Diagnosis also needs a tight red reproduction, supported cause, cleanup,
and a regression test at an approved seam; if no sound seam exists, record an
`/improve-codebase-architecture` follow-up instead of a shallow test.

Apply `review-fix-loop` directly in this orchestrator at `ticket-base`; do not
spawn a loop coordinator. Write its `LOOP_GATE` into `tickets.<id>.loop.gate`,
then require `LOOP_GATE.verdict: PASS` recorded there, zero open confirmed
findings, required validation, and a clean tree. A skipped Spec, a paused loop,
or an absent verdict blocks the PR: an unwritten gate is a skipped gate, and
neither a finished loop nor a zero burden says which axes ran.

Before opening the PR, reconcile every acceptance criterion and prove
`pr-base...HEAD` contains only this ticket. After creation, verify its remote
head equals the reviewed `HEAD`, its base is `pr-base`, and its URL is recorded,
then follow `references/pr-stack.md`: record the checks, mark the PR ready once
it passes net of `ci_baseline`, and pause on a failing check the ticket broke.
Set the tracker to `in review` and start the next ticket in a new environment.
If push or PR creation fails, pause first. An older single-branch run instead
follows `references/recovery.md`.

## Finish

Report ticket order, bases, environments, branches, commits, validation,
review-fix results, check status, tracker state, and the ordered PR stack.
Every accepted ticket must have one PR URL. End with one landable line:
`LANDABLE: yes` when every ticket is accepted with a green PR, or
`LANDABLE: no, <pr> <reason>` naming the first PR that blocks it. On `yes`, run
`/land-stack` when `--land` was given; otherwise tell the user that one command
merges the stack, closes the tickets, and removes the worktrees.
