---
name: orchestrate-implementation
description: "Run an approved ticket graph serially in fresh BB threads and open one reviewed pull request per ticket."
argument-hint: "<spec, ticket set, or ticket references>"
disable-model-invocation: true
---

# Orchestrate Implementation

Run Matt Pocock's `/to-spec` and `/to-tickets` output. One ticket owns one
branch, one BB environment, one review-fix gate, and one pull request.

Send raw bugs through `/triage` first. If a bare Spec needs several contexts,
pause and ask the user to run `/to-tickets`.

## Contract

- Keep work serial. One orchestrator worker is active at a time;
  `/code-review` may create only its required Standards and Spec subagents.
- Use a fresh thread for implementation, diagnosis, each review-fix phase, and
  PR writing. Apply `review-fix-loop` in this orchestrator so it spawns only
  those phase workers. One ticket shares one environment; the next gets a new
  branch and environment. Spawn, never fork.
- Pin the graph, target branch, and each `ticket-base`. Mutating workers commit
  and leave a clean tree; reviewers and checkers preserve it.
- Opening a draft PR and pushing its ticket branch are part of this skill.
  Merging, deploying, archiving, and cleanup remain separate actions.
- Leave a ticket open or `in review` until its PR merges. Never close it merely
  because implementation or review passed.
- Use ticket acceptance criteria as scope and leave the parent Spec unchanged.
- Cross-ticket integration belongs to an explicit approved ticket. Do not make
  an implicit cumulative implementation or final mega-PR.

## Prepare

1. Use `bb-cli` to resolve the project, provider, target branch, remote, clean
   committed `HEAD`, tracker, Spec, tickets, blocking edges, and current PRs.
   Freeze the graph; pause on non-ready tickets, missing edges, or cycles.
2. Snapshot the approved artifacts once. Record graph state, bases, branch and
   environment IDs, workers, commits, finding dispositions, and PR URLs under
   `$BB_THREAD_STORAGE`. Reconcile the ledger with BB, Git, GitHub, and the
   tracker before one transition on resume.
3. Verify `bb-cli`, `implement`, `diagnosing-bugs`, `tdd`, `code-review`,
   `review-fix-loop`, and `pr-writer`, plus authenticated push and PR access.
   Leave unrelated source checkout changes untouched.

## Wait

Use `bb thread wait <id> --timeout 1200 --json`. A timeout means the worker is
not idle yet; it is not a failed phase. Compare work status, latest event
sequence, interactions, and Git state. Progress starts another wait. After two
unchanged windows, inspect the log and interactions, then send one status
`tell`. One more unchanged window pauses. A user stop or pending question
pauses at once. Never spawn the next worker before the prior one is idle and
inspected.

## Start a ticket

Choose the first ready ticket in published dependency order. Open a linear PR
stack so work can continue without combining ticket diffs:

- The first ticket branches from the target branch.
- Each later ticket branches from the exact accepted head of the previous
  ticket and its PR targets that previous ticket branch.
- When a parent PR merges, retarget its oldest open child to the target branch
  only after proving the child diff still contains one ticket.

Create a managed environment at that base and record `ticket-base`, `pr-base`,
and `ticket-branch`. A dirty or drifting base pauses the run.

## Worker prompts

Implementation:
```text
/implement <attached full ticket>
Use the approved seams. Validate, commit, and leave the tree clean. End before /code-review.
```

Diagnosis:
```text
/diagnosing-bugs
Fix the attached ticket through all six phases. Validate, commit, and leave the tree clean.
```

Pull request:
```text
/pr-writer
Push exact clean HEAD and open a draft PR from <ticket-branch> into <pr-base> for <ticket>. Return its URL and base/head SHAs.
```

## Gates

Planned behavior or a known fix uses `/implement`; a hard, unexplained,
intermittent, or performance defect uses `/diagnosing-bugs`.

Implementation must advance from `ticket-base`, pass required validation, and
leave a clean tree. Diagnosis also needs a tight red reproduction, supported
cause, cleanup, and a regression test at an approved seam. If no sound seam
exists, record an `/improve-codebase-architecture` follow-up instead of a
shallow test.

Apply `review-fix-loop` directly in this orchestrator at `ticket-base`; do not
spawn a loop coordinator. Require `LOOP_GATE.verdict: PASS`, zero open confirmed
findings, required validation, and a clean tree. A skipped Spec or paused loop
blocks the PR.

Before opening the PR, reconcile every acceptance criterion and prove
`pr-base...HEAD` contains only this ticket. After creation, verify its remote
head equals the reviewed `HEAD`, its base is `pr-base`, and its URL is recorded.
Set the tracker to `in review`, then start the next ticket in a new environment.
If push or PR creation fails, pause before advancing the graph.

## Cumulative-run recovery

If an older run put accepted tickets on one branch, stop new work and preserve
it. Use the ledger's accepted heads to create branch refs without rewriting
commits, then open oldest-first stacked PRs whose diffs each map to one ticket.
Keep dirty in-flight work on its current ticket until clean and accepted. Pause
if any ticket base, accepted head, or diff ownership cannot be proved.

## Finish

Report ticket order, bases, environments, branches, commits, validation,
review-fix results, tracker state, and the ordered PR stack. Every accepted
ticket must have one PR URL; merge the stack oldest first in a separate run.
