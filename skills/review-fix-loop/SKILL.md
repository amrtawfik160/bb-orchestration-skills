---
name: review-fix-loop
description: "Review and fix a committed diff in fresh BB threads until both axes reach zero."
argument-hint: "<fixed-point> [spec or ticket reference]"
disable-model-invocation: true
---

# Review Fix Loop

Orchestrate this serial loop in BB:

```text
review (Standards -> Spec) -> findings -> fix -> fresh review
                           -> 0 + 0 ----------------> finish
```

Use `bb-cli` for BB operations and `code-review` for the review rubric.

## Rules

- Keep one worker active at most. Every review and fix gets a fresh spawned
  thread, parented to this orchestrator, in one cumulative run environment.
- Never fork or reuse a worker. Workers act directly: no subagents, delegation,
  worker-created threads, or background agents.
- Pin one review-base. Every review covers `review-base...HEAD`, including all
  fixes.
- Reviews are read-only. Fixes are committed, validated, and clean.
- One reviewer performs Standards first and Spec second, sequentially. This
  overrides `code-review`'s parallel step.
- Finish only on a fresh review with zero findings on both axes.
- Do not push, open or merge PRs, deploy, archive, or clean up unless separately
  asked.

## Prepare

1. Inspect BB and Git state. Resolve the fixed point from the argument or the
   immediately preceding `/code-review`, then pin `initial-head` and
   `review-base = merge-base(fixed-point, initial-head)`. Require a non-empty,
   committed diff.
2. Resolve and read the Spec using `code-review`'s lookup order. If the issue
   tracker is not configured, request `/setup-matt-pocock-skills`. A preceding
   review report is context only, never an accepted loop iteration.
3. Freeze mutable Specs, tickets, standards, tracker configuration, and agent
   instructions as hashed BB attachments outside the repo. Use committed bytes
   for clean committed inputs.
4. Reuse the source environment only when clean. Otherwise create one managed
   BB worktree from `initial-head`, leave the source checkout untouched, and
   use that environment for the whole loop. Uncommitted code is excluded; if
   the user wants it reviewed, require a committed baseline.
5. Pin one provider and verify the run environment has `bb-cli`, `code-review`,
   and `tdd`.

Keep a ledger under `$BB_THREAD_STORAGE` with the pinned inputs, environment,
SHAs, phase, workers, commits, and gates. Reconcile it with BB and Git on resume.

Before each spawn, require the previous worker to be idle. Waiting is bounded
observation: use `bb thread wait <id> --timeout 60 --json`. After each timeout,
record a **heartbeat** from its status, latest event sequence, interactions,
Git state, descendants, and background work. Any change resets the stale count.

Five consecutive timeouts without a heartbeat is a stall; never lengthen the
wait. Inspect show, output, the paged log, interactions, and topology. Honor a
user stop or pending question. Otherwise send one corrective `tell` to the same
worker; if the next sample is unchanged, pause and report. If the user asked
only to wait, that forbids `tell`, stop, or spawn—not heartbeat checks. Pause
and report the stall. Do not issue another wait until the user resumes.

After a worker becomes idle, inspect its output, Git state, and BB topology.
Accept it only if it ran alone and left no descendants or background work.

## Loop

### Review

Capture `review-start = HEAD` and spawn a fresh read-only reviewer. Give it the
review-base and frozen Spec. Require every finding to include an ID, axis,
location, evidence, and fix, followed by:

```yaml
REVIEW_GATE:
  standards_findings: <integer>
  spec_findings: <integer>
  total_findings: <integer>
  verdict: PASS|CHANGES_REQUESTED
```

Counts must match the listed findings and their sum. Accept the review only if
`HEAD` still equals `review-start`, the tree is clean, and the worker rules
held. Attributable uncommitted review edits may be restored by that reviewer,
but discard its report and review fresh. A staged or committed review pauses
the run; do not rewrite history.

If the gate is `0`, `0`, `0`, `PASS`, finish. Otherwise fix.

### Fix

Capture `fix-base = HEAD` and spawn a fresh fixer with the complete review and
frozen inputs. It addresses every finding, uses `/tdd` for behavioral changes
where appropriate, validates, and leaves the tree clean.

- If any finding is accepted, require a commit after `fix-base`, with
  `fix-base` still its ancestor.
- If all findings are disputed, require `HEAD = fix-base` and evidence for each
  dispute.

Re-review in a fresh thread from the original review-base. Do not pass it the
previous verdict. Persisting findings become diagnosis work for the next fresh
fixer; never waive them or impose a retry limit while safe progress remains.

## Finish

Report the run environment and branch, review-base, initial and final `HEAD`,
ordered worker IDs, fix commits, validations, loop count, and final gate.
