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

- Keep work serial. One orchestrator worker is active at a time;
  `/code-review` may create only its required Standards and Spec subagents.
- Use a fresh thread for implementation, diagnosis, each review-fix phase, and
  PR writing. Apply `review-fix-loop` in this orchestrator so it spawns only
  those phase workers. One ticket shares one environment; the next gets a new
  branch and environment. Spawn, never fork.
- Pin the graph, target branch, and each `ticket-base`. Mutating workers commit
  and leave a clean tree; reviewers and checkers preserve it. Verify every
  worker claim in the worktree before recording it.
- Opening a draft PR and pushing its ticket branch are part of this skill.
  Merging, closing tickets, and archiving environments belong to `land-stack`,
  which `--land` invokes once the whole graph is accepted. Deploying stays out.
- Leave a ticket open or `in review` until its PR merges. Never close it merely
  because implementation or review passed.
- Use ticket acceptance criteria as scope and leave the parent Spec unchanged.
- Cross-ticket integration belongs to an explicit approved ticket. Do not make
  an implicit cumulative implementation or final mega-PR.

## References

Follow `../review-fix-loop/references/bb-workers.md` for spawning, waiting,
interactions, verification, budgets, pausing, notification, and auto-resume,
and attach `../review-fix-loop/references/worker-footer.md` to every worker.
Keep the ledger in `references/ledger.md`. After a PR opens,
`references/pr-stack.md` owns checks, ready state, merges, rebases, and review
comments.

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
3. Snapshot the approved artifacts once and write the run ledger. `resume`, or
   an existing ledger at start, reconciles it with BB, Git, GitHub, and the
   tracker before one next transition.
4. Verify `bb-cli`, `implement`, `diagnosing-bugs`, `tdd`, `code-review`,
   `review-fix-loop`, `show-me`, `gh-axi`, and authenticated push and PR
   access. Leave unrelated source checkout changes untouched.

## Start a ticket

Choose the first ready ticket in published dependency order, then branch it so
each PR keeps a one-ticket diff. The first ticket branches from the target
branch. Each later ticket branches from the exact accepted head of the previous
ticket, and its PR targets that previous ticket branch. Create a managed
environment at that base and record `ticket-base`, `pr-base`, and
`ticket-branch`. A dirty or drifting base pauses the run.

## Worker prompts

Every prompt ends with `End with the attached WORKER_RESULT footer.`

Implementation:
```text
/implement <attached full ticket>
Use the ticket's seams, or the project's documented test seams. Validate, commit, and leave the tree clean. End before /code-review.
```

Diagnosis:
```text
/diagnosing-bugs
Fix the attached ticket through all six phases. Validate, commit, and leave the tree clean.
```

Pull request:
```text
Push exact clean HEAD, then open a draft PR from <ticket-branch> into <pr-base> for <ticket> with `gh pr create --draft`, or gh-axi if installed. Title it from the ticket summary.
For the body use /show-me: the smallest diagram, call tree, or diff shape that shows what this ticket changed, plus two sentences of context. No HTML file.
Return its URL and base/head SHAs.
```

## Gates

Planned behavior or a known fix uses `/implement`; a hard, unexplained,
intermittent, or performance defect uses `/diagnosing-bugs`. Implementation
must advance from `ticket-base`, pass required validation, and leave a clean
tree. Diagnosis also needs a tight red reproduction, supported cause, cleanup,
and a regression test at an approved seam; if no sound seam exists, record an
`/improve-codebase-architecture` follow-up instead of a shallow test.

Apply `review-fix-loop` directly in this orchestrator at `ticket-base`; do not
spawn a loop coordinator. Require `LOOP_GATE.verdict: PASS`, zero open confirmed
findings, required validation, and a clean tree. A skipped Spec or paused loop
blocks the PR.

Before opening the PR, reconcile every acceptance criterion and prove
`pr-base...HEAD` contains only this ticket. After creation, verify its remote
head equals the reviewed `HEAD`, its base is `pr-base`, and its URL is recorded,
then follow `references/pr-stack.md`: wait for checks, mark the PR ready on a
pass, and pause on a failing check. Set the tracker to `in review` and start the
next ticket in a new environment. If push or PR creation fails, pause first.
An older single-branch run instead follows `references/recovery.md`.

## Finish

Report ticket order, bases, environments, branches, commits, validation,
review-fix results, check status, tracker state, and the ordered PR stack.
Every accepted ticket must have one PR URL. End with one landable line:
`LANDABLE: yes` when every ticket is accepted with a green PR, or
`LANDABLE: no, <pr> <reason>` naming the first PR that blocks it. On `yes`, run
`/land-stack` when `--land` was given; otherwise tell the user that one command
merges the stack, closes the tickets, and removes the worktrees.
