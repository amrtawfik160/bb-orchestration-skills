# Changelog

## 2026-09-14 — User stops stick, relay probe goes free

A live run wrote the findings. The user stopped a check worker, then the
orchestrator mid-ledger-write; the protocol had no rule for either, so the
footer chase would have resumed past the stop and the watchdog would have
re-armed past it.

### Stopped workers pause, never respawn

A missing footer is now checked for a user stop before it is chased:
`bb thread log --limit 1` ends with `Stopped manually`, and that pauses with
`class: decision`, the worker ID, and the partial output as evidence. Only
the user resumes past their own stop. The check costs one bounded read in
one branch; the listen-only wait path is untouched.

### The watchdog leaves user-stopped threads alone

The watchdog skips a thread with a `manual-stop` interrupt in the last 30
minutes, mirroring the recent-failure guard. A user stop is a decision, and
re-arming past it would override one. The guard expires, so a run the user
abandons without resuming still re-arms within half an hour of the stop.

### Relay reads context free first

The relay context check prefers `bb thread context --self --json`, which
reads recorded usage without a model request, and falls back to the full-log
`contextWindowUsage` probe only when usage is null. The relay scope also
names `verify-landing`, which runs on the shared run ledger like
`land-stack`.

## 2026-09-14 — Listen-only wait: no polling, no log reads, no status nudges

The Wait protocol burned credits on both sides of every phase: each
20-minute timeout fetched `show`, a full `--after-seq` log page, and the
interaction list, stuffed hundreds of worker events into the orchestrator's
context to compare "windows", and after two unchanged windows interrupted
the worker with a "Report your status" tell. `bb-cli` says plainly: let
threads work after spawning; do not poll with shell sleeps, repeated log
reads, or repeated status reads. The protocol now obeys it.

### One blocking wait covers a phase

`bb thread wait` blocks server-side, so waiting costs one call no matter how
long the phase runs, and the parent receives lifecycle notifications when a
child completes, fails, or is interrupted. On a timeout the orchestrator
checks only the two things that can block silent progress — `thread.show`
status and the interaction list — then waits again. The log is never read
while waiting, and a working worker is never asked for status.

Stall detection moves from fetched windows to elapsed time: each timeout
consumes 20 minutes of the ticket minutes budget, and exhaustion pauses with
`reason: budget`. Error handling is unchanged (one retry, the queued
provider retry counts), and a pending interaction is still handled before
the next wait.

### `last_seq` retires

With no paging, no sequence is tracked: `last_seq` leaves the worker records
and field notes of all three ledgers. Old ledgers keep the field as inert
history; resume ignores it. The `cli-semantics` suite drops the
`--after-seq` behavior pins it no longer depends on, and both it and
`wait-policy` now reject polling residue (`after-seq`, `LAST_SEQ`,
`unchanged window`, `Report your status`) from the protocol.

## 2026-09-14 — End-to-end hardening: verify-landing, quarantine, run-status

The cycle used to end at merge: `land-stack` retired the worktrees and never
confirmed the target stayed green, flakes looped without escape, and the only
way to read a run was the sidebar. Three additions close those gaps.

### Verify-landing proves the target

New `verify-landing` skill, invoked by `land-stack` after the last merge.
Each landed merge verifies oldest first in its own visible BB thread sharing
one worktree at the target head: merge-commit checks green net of the CI
baseline and quarantine, plus a smoke run. The run ledger gains a
`verification` object and per-ticket verification records, the protocol gains
a `[continuation] verify-landing` template, and the run ends with a
`VERIFY_GATE` footer.

A merge that turns the target red follows `references/red-main.md`: baseline
and quarantined failures report and continue, anything else is a red target.
Fix forward only when the cause is known and one ticket heals it within one
cycle; otherwise revert first through the `land-stack` gate, file the fix as
`ready-for-agent`, and notify. Silence is the only forbidden move.

### Quarantine and reopen budget

New `review-fix-loop/references/quarantine.md`. Two exact flake patterns
(re-run green with no code change, alternating red-green-red across three fix
commits) move a check into `quarantine[]` with a `ready-for-agent` repair
ticket labeled `flaky`; gating excludes it only with the ticket recorded.
The loop ledger gains `attempts[]` evidence and `quarantine[]`, and the land
gate merges through quarantined failures the way it already merges through
the baseline.

The reopen budget caps cycling without touching convergence: a stable finding
ID that returns RESOLVED to OPEN twice pauses with a diagnosis bundle, while
`best-burden` still has no attempt counter and converging work still runs to
zero under the worker budget. The loop absorbs this in its last two lines of
compactness budget.

### Run-status reads without touching

New `run-status` skill: one ledger plus read-only thread and PR state,
rendered in a shared four-section format (run, tickets, blockers, children)
that names pauses, quarantines, red-main responses, and missing gate
verdicts. Read-only and single-turn by contract: no spawns, no writes, no
continuation. The orchestrator's `status` mode renders through it.

## 2026-09-14 — Audit pass: relay handoff specified, prompts disclosed, pointers trimmed

A writing-for-agents audit of the skill set. Two structural fixes and a
round of pointer and duplication pruning.

### The relay handoff is now exact

The successor relay named a `$CONTINUE_PROMPT` variable but never gave its
text, and the successor side was one vague line. It now has an exact handoff
template (save the ledger to your own storage, record `relay.predecessor`,
reconcile, continue per skill), a scope rule (ledgers tracking `relay`:
orchestrate, cleanup, and land-stack via the shared run ledger; standalone
loops use continuation instead), and `relay` fields in the cleanup ledger.

### Cleanup prompts move beside orchestrate's

`codebase-docs-cleanup` kept 31 lines of worker prompts inline between Plan
and Gates while serving three scattered sections. They now live in
`references/worker-prompts.md` like the orchestrator's, under the same
four-line prompt budget.

### Pointers and single sources

- Skill descriptions trimmed: the loop loses its tautology branch, cleanup
  loses mechanism and constraint clauses, land loses its hardwired branch,
  show-me collapses four synonyms into one trigger.
- The six drifting phase enumerations collapse to "every phase", with the
  `phase:` enum in `worker-footer.md` as the single source of truth. The
  loop's intro and contract had already drifted (recovery present, then absent).
- The orchestrator states its loop rule once (in Gates, where `ticket-base`
  lives) instead of twice.
- Worker titles follow `<ticket-id> <phase>`, and the spawn record verifies
  `.thread.visibility` is `visible`: a worker the sidebar cannot see is a
  spawn bug.
- Phase workers spawn only through `bb thread spawn`: provider-native agent
  tools keep work inside the thread with no BB child, no worktree isolation,
  and no sidebar row.
- Reference pointers gain conditions (which prompts file when; inventory
  during Inventory and Plan; pruning per batch), the loop's environment reuse
  is split into resume-vs-fresh, and the worker-brief demand is sharpened to
  a self-containment bar.
- `bb-workers.md` gets a 550-line test budget so the next addition has to
  earn a split instead of accreting. The version pin in `subagents.md` gets
  an explicit re-check-on-upgrade note.

## 2026-09-13 — Continuations queue at turn end and name their ledger

A cleanup run showed the problem in the IDE: a cryptic `Queue 1` row reading
`Continue this run from its ledger`, sitting there for the whole turn. The
protocol queued the continuation as soon as the turn started working, and
every queued row renders in the user-visible Queue panel.

### Queue late, name the ledger

The continuation is now queued as the turn ends, not as it starts, so the
Queue panel holds a brief `[continuation]` row between turns instead of a
persistent badge during work. Each skill has an exact template that names
itself and its ledger path, with a guard that ends terminal or paused wakes
silently instead of re-queueing. Before queueing, the agent deletes stale
continuation rows (including legacy generic text) so wakes never stack, and
the docs say the row is safe to ignore or delete.

### The watchdog covers the gap

Queue-at-start existed so an interrupted or errored turn would still
continue. That job now belongs to the watchdog, which already re-armed
orchestrators found idle or errored with an empty queue. It now scans
cleanup and standalone loop ledgers too, names the exact ledger path in its
re-arm message, and tolerates ledgers without a relay field, so one
automation still covers every run of the project. `codebase-docs-cleanup`
creates the watchdog and tracks `continuation_message` like the run ledger;
it previously defined no continuation behavior at all, which is why the
cleanup agent improvised the generic row.

## 2026-09-13 — Every phase runs in its own visible BB thread on a chained ticket worktree

The single-thread shared-checkout experiment is reversed. Long runs hid all
their work inside one conversation, which made them impossible to watch and
wasted BB's thread model. The default is BB threads again, with visibility
fixed so the run is watchable from the IDE.

### One visible thread per phase, one chained worktree per ticket

Each ticket gets its own managed worktree, chained from the previous ticket's
accepted head. Implementation, review, finding checks, fixes, closure checks,
rebases, and PR work each run in a fresh visible BB thread sharing that
ticket's worktree. Workers spawn with `--visibility visible` and are stopped
after their result is recorded, so the thread and log stay inspectable from
the sidebar instead of piling up hidden.

### What changed

- `orchestrate-implementation`, `review-fix-loop`, `land-stack`, and
  `codebase-docs-cleanup` all default to BB worker threads. The in-thread
  sub-agent protocol stays only as an explicit alternative for users who ask
  for single-thread execution.
- The PR worker is a fresh thread again: it pushes the exact clean head and
  opens the draft PR with a `show-me` body, instead of the parent doing it
  inline.
- Landing retires each ticket worktree after its merge is confirmed on the
  remote. There is no shared checkout to preserve.
- Pause records no longer carry a worker-visibility promotion: workers are
  already visible, so a blamed worker is just opened. A legacy hidden worker
  is promoted before opening.
- Budgets count visible workers from the ledger, with `bb thread count` able
  to see them; the hidden-thread exclusion note now covers legacy runs only.

## 2026-09-07 — A waiting run no longer spins, and a lost continuation no longer strands it

Two live runs showed both problems in one afternoon.

### Waiting is done inside the turn

An orchestrator with nothing to do but wait for a worker or for CI used to end
its turn and immediately wake itself again, every 25 seconds, for hours. Each
wake re-read its whole context to re-check one pull request. It now waits on a
running worker inside the turn, and when only CI is pending it schedules its
next wake ten minutes out. A check that finds nothing changed no longer counts
as progress, and the no-progress stop only applies when nothing is pending.

### A watchdog catches a lost continuation

BB was seen deleting a run's queued "continue" message without ever delivering
it, which left the run idle with work in flight and nothing to wake it. Every
run now creates one small scheduled check that re-arms any run found idle with
an empty queue while its ledger still says it is running. One check covers every
run in the project, including after a hand-off to a fresh thread.

## 2026-09-07 — The worker checks match the installed BB again

Every `bb` command the skills rely on was run against BB 0.42.1. Four did not
do what the docs said, and the tests now pin each one.

### The clean-tree check could never pass

After a worker committed, the orchestrator was told to look for a `clean`
working tree. BB reports a committed branch as `committed_unmerged`, so every
honest worker looked dirty. The check now reads the flag BB actually sets for
uncommitted changes.

### Reading a busy worker's log no longer breaks

The log page used while waiting on a worker stopped after 100 events and added
a note after the JSON, which broke the parser on any busy window. The command
now asks for the whole remainder as one valid page.

### Remote validation reads the real exit code

Validation run on another machine looked for the exit code in the wrong place.
It is read from the terminal session record now, with a timeout long enough for
a real test suite.

### The cleanup inventory no longer fails at its first step

Listing subsystems sent an empty search, which BB rejects. The listing now asks
for every directory.

### The bundled `bb-cli` copy goes stale after a BB upgrade

BB installs its `bb-cli` skill into the Claude and agents skill folders, but a
BB upgrade does not refresh those copies. A stale copy describes commands that
no longer exist and misses ones that do. The README now says how to check and
refresh it.

## 2026-09-07 — Runs finish on their own now

Two real runs were checked. Neither reached the end, and both stopped for
reasons that were the skill's fault rather than the work's.

### It stopped asking you to say "continue"

The biggest problem: after each piece of work the run just ended its turn and
waited. One run needed 52 nudges and still only got through 8 of 19 tickets.
A run now queues its own next step before the turn ends, so it keeps going until
it is genuinely finished or genuinely needs you. When it grows too large for one
conversation, it hands the whole thing to a fresh one and tells you where it
went.

### A repository that was already broken no longer blocks everything

Both runs stalled on tests that were failing on the main branch *before any work
started*. Every pull request inherited those failures, so none of them could
ever be marked ready, and nothing could merge. The run now records what was
already failing at the start and stops blaming the tickets for it. Those
failures are reported, not hidden.

### Pull requests stop getting forgotten

Seven pull requests were left waiting on their checks and never looked at again,
because the run moved on and nothing brought it back. Every turn now starts by
re-checking the open pull requests and marking ready whatever passed.

### The review gate has to be written down

One run marked tickets reviewed without ever recording the review's verdict.
That is now required in writing before a pull request can be opened — an
unrecorded gate counts as a skipped one.

### Flaky tests get caught

A bug slipped through and needed repairing after the fact because a timing test
passed once by luck. Work that touches time, clocks, ordering or randomness now
gets its tests run repeatedly instead of trusted after a single green run.

### Smaller fixes

Paused runs must say why they paused, or the automatic retry never sees them.
And a notification is only recorded once it has actually been shown to work.

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
