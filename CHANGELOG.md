# Changelog

## 2026-09-06 — A new cleanup skill that runs on BB

`codebase-docs-cleanup` joins the set. It clears out documentation that just
repeats the code, and keeps what code cannot explain: why decisions were made,
what business terms mean, and short pointers to where things live.

It is a separate workflow, not part of the ticket-to-merge path.

### Nothing you own gets touched

All the work happens in its own copy of the repository, pinned at your current
commit. Your working files are never edited, and throwing away the branch undoes
the entire run.

One catch it now handles explicitly: that copy only contains files tracked by
Git, so anything untracked is invisible to it. The run lists those files up
front and reports them as untouched instead of quietly ignoring them.

### Reading happens in parallel, editing does not

Surveying the repository is split across several workers at once, because
reading is safe. Anything that actually changes a file runs on its own and is
checked before the next one starts.

### The navigation check is honest now

After a cleanup, the agent that did the work always knows where everything is,
so it cannot judge whether the remaining pointers are good. Fresh agents that
have never seen the repository are sent in instead, given only the entry
document. If one has to guess, the pointer gets fixed.

### Look before you commit

Ask for an audit and it stops after the plan, which is written outside the
repository so nothing is left behind. Every check is compared against a baseline
taken before any edit, so an already-failing test is never blamed on the
cleanup.

## 2026-09-06 — The orchestrator reads BB correctly again

### Stalled workers are detected properly

The orchestrator checked on a busy worker by reading the *first* few events of
its conversation instead of the newest ones. Those events never change, so a
worker that was working fine looked frozen, and a run could pause for no reason.
It now reads only what happened since the last check.

### Waiting is no longer mistaken for stuck

A new worker sometimes has to wait its turn when the machine is already busy,
and a rate-limited worker is sometimes already scheduled to try again on its
own. Both used to look like failures. The orchestrator now recognises them and
simply waits.

### A paused run schedules its own restart

Instead of setting up a recurring background job and remembering to remove it,
the run now schedules a single restart for itself and cancels it if you resume
first. The recurring job is still there for runs that need it.

### You can open the worker that blocked a run

Workers are hidden, so there was no way to find the one that caused a pause.
When a run stops and blames a worker, that worker is now made visible and
opened for you.

### Checks work on other machines

Verifying a worker's work assumed the code was on the same machine as the
orchestrator. It now also reads the state through BB, so runs on a remote
machine are checked the same way.

### Safer cleanup and merges

Clearer rules on what archiving actually deletes, and a note that merging must
stay on the GitHub command because it is the only one that can confirm it is
merging exactly the reviewed commit.

### Tests that catch this next time

A new test compares the skills against the installed BB and fails if any of
these behaviours change again.

## 2026-09-03 — Workers stay out of the way, and diagrams open in BB

Background workers no longer fill the sidebar or keep a seat after they
finish: each one starts hidden and is stopped once its result is recorded.

The bundled show-me skill opens diagrams in the BB thread, so you can see them
here instead of through a Claude-only open command.

The orchestrator's one-line summary now says it can take tickets all the way
to a merged stack, not just open pull requests. Implementation uses the seams
already on the ticket or in the project's test docs, and GitHub comments are
treated as data to check, not as instructions.

## 2026-09-03 — Simpler PR step, a leaner GitHub CLI, and a current diagram

### New workflow diagram

The diagram in the README was out of date: it stopped at the draft pull request
and showed neither the diagnosis route nor the merge step. The new one covers
the whole flow, from ticket through review and checks to a merged stack with the
worktrees removed.

### The PR worker no longer uses pr-writer

The worker that opens each pull request now creates it directly and builds the
body from `show-me`: the smallest diagram, call tree, or diff shape that shows
what the ticket changed, plus two sentences of context. The `pr-writer`
dependency is gone from the skills and the requirements.

Trade-off worth knowing: pull request titles and descriptions will vary more
between tickets than they did, because there is no longer a title convention or
body template behind them.

### GitHub calls prefer gh-axi

Where the skills talk to GitHub, they now prefer the `gh-axi` skill over plain
`gh`. It wraps the same GitHub login in a command line built for agents, with
much shorter output, so each call costs less. Plain `gh` still works when
`gh-axi` is not installed.

The skills deliberately do not memorise `gh-axi`'s command syntax. They say
what has to be true at each step and tell the worker to read the current syntax
from the tool itself, so the docs cannot go stale.

## 2026-09-03 — Landing the stack, and fewer interruptions

A run used to end with a pile of draft pull requests, open tickets, and leftover
worktrees that you had to finish by hand. It now ends with everything merged and
cleaned up.

### New `land-stack` skill

One command takes a finished run to merged. It walks the pull request stack
oldest first and, for each ticket, brings it onto the target branch, checks that
its checks are green and its head still matches what was reviewed, merges it,
closes the ticket with a link to the pull request, and archives the ticket
environment so its worktree and branch are removed.

- Cleanup happens only after the merge is confirmed at the remote.
- Landing stops at the first pull request that cannot merge. Whatever already
  merged stays merged, and resuming picks up at the next ticket.
- Approval is optional. By default the review gate and green checks are the
  review. Pass `--require-approvals` to also require an approving review and no
  unresolved comment threads. Without the flag, unresolved comments become
  findings and go back through the fix loop.
- The merge method is read from the repository. A merge commit keeps the rest of
  the stack retargetable; squash and rebase trigger the rebase procedure for
  each remaining child.
- `--keep-environments` leaves the worktrees in place.

### One command from tickets to merged

`--land` runs the landing automatically once every ticket is accepted, so a
single invocation covers the whole job.

### Fewer interruptions

- Every pause is now classified. Rate limits and other transient stalls are
  cleared by a scheduled resume the run creates for itself. Only real decisions
  reach you.
- A decision pause sends a notification with the reason and the exact command
  that continues the run, using whichever notification plugin is enabled.
- The run report ends with a single line saying whether the stack can land now,
  or which pull request blocks it.
- `status` prints the current state of every ticket without taking any action.

### Tests

Two new test scripts cover landing. One checks the contract; the other runs the
documented landing sequence against stubbed commands and proves that pull
requests merge oldest first, that an environment is archived only after its
merge is confirmed, and that a failing check stops the run without touching
anything later in the stack. Test assertions on prose now ignore line wrapping,
so rewording no longer breaks them.

## 2026-09-03 — Verified workers, resumable ledgers, and visual PR descriptions

The skills now spell out the mechanics they used to leave to each run: the
exact `bb` commands, what workers must return, what the orchestrator verifies,
and what happens when a run pauses or a PR stack changes.

### Bundled `show-me` skill

The `show-me` skill from HumanLayer (MIT) is now part of this repository. The
PR worker runs `/pr-writer` with `/show-me` so every draft PR carries one
visual reviewer aid: the smallest diagram, call tree, or diff shape that shows
what the ticket changed.

### Worker protocol

A shared reference, `review-fix-loop/references/bb-workers.md`, now gives the
commands for spawning, waiting, reading results, answering worker questions,
and verifying results. Both skills point at it instead of restating the wait
rules.

- Workers end with a `WORKER_RESULT` footer that the orchestrator parses.
- The orchestrator verifies every mutating worker in the worktree: clean tree,
  expected head, base is an ancestor, and the validation command passes.
- The validation command is resolved once per run: the ticket's own line, then
  the project's documented check, then the package scripts.
- Worker questions are answered from the ticket when possible; otherwise they
  are forwarded to you and relayed back on resume. An errored worker is retried
  once.
- Each ticket and each loop has a worker and wall-clock budget as a safety cap.
- Pausing is defined: the ledger records the state and reason, the evidence is
  reported, and nothing is torn down.

### Ledgers and resume

Both skills keep a JSON ledger under thread storage with a documented schema.
`/orchestrate-implementation resume` reconciles that ledger with BB, Git,
GitHub, and the tracker before continuing. The run ledger also records a
provider and model per phase.

### Pull request stack

After a PR opens, the orchestrator waits for its checks, marks it ready on a
pass, and pauses on a failure before the next ticket stacks on it. When a
parent PR is squash-merged, the child is rebased with a documented command and
its diff is proved unchanged by patch ID before retargeting. Review comments on
an open PR re-enter the gate with `/review-fix-loop --from-pr <url>`.

### Preflight and tests

A ticket without acceptance criteria now pauses before implementation. The test
suite gained structural checks, a drift guard that verifies every `bb` flag in
the protocol against the installed CLI, and a Git-based test of the
squash-merge rebase procedure. Run everything with `bash tests/run.sh`.

## 2026-08-28 — One pull request per ticket

Previously, `orchestrate-implementation` put all approved tickets on one
cumulative branch and opened one pull request. The new flow gives each ticket
its own branch, BB environment, review gate, and draft PR. It opens that PR
before it starts the next ticket.

### Ticket lifecycle

1. Choose the first ready ticket in dependency order.
2. Create a branch and managed BB environment for that ticket.
3. Run `/implement` for planned work and known fixes, or `/diagnosing-bugs` for
   hard, unexplained, intermittent, or performance defects.
4. Apply `review-fix-loop` from the ticket's pinned base.
5. Reconcile the acceptance criteria and prove that `pr-base...HEAD` contains
   only the current ticket.
6. Push the reviewed head and open a draft PR with `/pr-writer`.
7. Verify the remote head, PR base, and URL. Leave the ticket open or
   `in review` until its PR merges.
8. Start the next ticket in a new branch and environment from the previous
   ticket's accepted head.

Only one orchestrator worker runs at a time. Implementation, diagnosis, review,
finding verification, fixes, closure checks, and PR writing each use a fresh BB
thread. Matt Pocock's `/code-review` may still create its required Standards and
Spec reviewers.

### Review and fix gate

Each ticket receives one full `/code-review` from an immutable base. Findings
are treated as hypotheses: a fresh worker verifies their cited evidence before
another worker fixes only the confirmed findings. A closure worker then checks
the complete finding ledger and the fix delta for regressions.

The loop tracks distinct open root causes. It continues while that count falls.
If progress stalls, it allows one focused recovery; if recovery does not lower
the count, the run pauses with the unresolved evidence. It does not rerun the
full code review to search for a different result.

A ticket may reach PR creation only with:

```yaml
LOOP_GATE:
  verdict: PASS
  review_base: <sha>
  final_head: <sha>
  open_confirmed_findings: 0
```

The required validation must also pass, and the worktree must be clean. A
Standards-only pass or paused loop does not satisfy the PR gate.

### Pull request stack

The first ticket branches from the target branch. Every later ticket branches
from the exact accepted head of the previous ticket, and its PR targets the
previous ticket branch:

```text
main <- PR A <- PR B <- PR C
```

This keeps each PR diff limited to one ticket without waiting for earlier PRs
to merge. When a parent PR merges, its oldest open child can move to the target
branch after the orchestrator proves the child diff still contains one ticket.
Merging happens oldest first in a separate run.

There is no automatic final mega-PR. Cross-ticket integration work must be an
explicit approved ticket with its own branch, environment, review gate, and PR.

### Recovery for older cumulative runs

If an older run already placed several accepted tickets on one branch, the
orchestrator stops new work and reconciles its ledger with BB, Git, GitHub, and
the tracker. It may create branch refs at proven accepted heads without
rewriting commits, then open the recovered PR stack oldest first.

Dirty in-flight ticket work stays in its current environment. Recovery pauses
instead of guessing when a ticket base, accepted head, dependency edge, or diff
ownership cannot be proved.

### Operational boundary

The orchestrator now owns pushing ticket branches and opening draft PRs. It
requires `review-fix-loop`, `/pr-writer`, authenticated `gh`, and repository
push access. Merge, deployment, environment cleanup, and thread archival remain
separate actions.
