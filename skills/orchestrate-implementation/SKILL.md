---
name: orchestrate-implementation
description: "Run an approved ticket graph serially in fresh BB threads, routing hard bugs through diagnosis and closing confirmed review findings."
argument-hint: "<spec, ticket set, or ticket references>"
disable-model-invocation: true
---

# Orchestrate Implementation

Run Matt Pocock's approved planning output: route each ready ticket, review it
once, close confirmed findings, then finish with one integration gate.

`/to-spec` and `/to-tickets` produce the approved artifacts. Their tickets are
already sized for one fresh context. Send raw bugs through `/triage` first.

## Contract

- Keep ticket work serial: one orchestrator-spawned BB worker is active at a
  time. `/code-review` may create its required Standards and Spec subagents;
  they create no descendants.
- Spawn a fresh thread for every implementation, diagnosis, review, finding
  check, fix, and closure check. Reuse one cumulative environment; never fork.
- Give each implementation or diagnosis worker one full ticket. If a bare Spec
  needs several contexts, pause and ask the user to run `/to-tickets`.
- Pin `run-base` and each `unit-base`. Mutating workers commit and leave a clean
  tree; reviewers and checkers preserve `HEAD` and the tree.
- Push, PR, merge, deploy, archive, and cleanup require separate requests.

## Prepare

1. Use `bb-cli` to resolve the project, provider, environment, branch, clean
   committed `HEAD`, tracker, full Spec, every ticket, and every blocking edge.
   Freeze the graph; pause on non-ready tickets, missing edges or cycles.
2. Snapshot the artifacts once and attach the same bytes to relevant workers.
   Record bases, graph state, worker IDs, and finding dispositions under
   `$BB_THREAD_STORAGE`. Reconcile the ledger with BB, Git, and the tracker on
   resume before taking one transition.
3. Reuse a clean environment or create one managed worktree at `run-base`.
   Leave unrelated source-checkout changes untouched.
4. Verify `bb-cli`, `implement`, `diagnosing-bugs`, `tdd`, and `code-review` in
   the selected environment. Spawn with explicit project, parent, environment,
   provider, attachments, and JSON output.

## Wait

Use `bb thread wait <id> --timeout 1200 --json`. A timeout means the worker is
not idle yet; it is not a failed phase. Compare work status, latest event
sequence, interactions, and Git state. Progress starts another wait. After two
unchanged windows, inspect the log and interactions, then send one `tell` asking
for status. One more unchanged window pauses. A user stop or pending question
pauses immediately. Never spawn the next worker before the current worker is idle and inspected.

## Route by uncertainty

- Planned behavior or a known fix uses `/implement`.
- A specific hard, unexplained, intermittent, or performance defect uses
  `/diagnosing-bugs`. It diagnoses the ticket, never review-loop convergence.

## Worker prompts

Implementation:
```text
/implement <full ticket or spec reference>
Use the attached approved seams. End after validation and a clean commit; the next fresh thread owns /code-review.
```
Diagnosis:
```text
/diagnosing-bugs
Fix the attached ticket through all six phases. End after cleanup, validation, and a clean commit; the next fresh thread owns /code-review.
```
Review:
```text
/code-review <base>
Spec: <attached ticket and parent Spec>.
Add to both axis briefs: "Do not invoke /code-review or spawn additional agents; perform this review directly." Keep the tree unchanged.
```
Finding check:
```text
Verify each attached finding against its citation and <base>...HEAD.
Consolidate the same root cause under one stable <axis>-<n> ID; return CONFIRMED or DISPUTED with evidence. Keep the tree unchanged.
```
Fix:
```text
Fix only the attached confirmed findings.
Use /tdd for behavioral fixes only at attached pre-agreed seams. Commit cleanly and report validation.
```
Closure check:
```text
Check the complete attached finding ledger and <fix-base>...HEAD. Reuse IDs for the same root cause. Return RESOLVED or OPEN; label only regressions caused by the fix CONFIRMED_FIX_REGRESSION.
Keep the tree unchanged.
```
Recovery:
```text
Recover the attached stalled root causes. For a stalled behavioral defect use /diagnosing-bugs and its tight red loop; otherwise correct the cited root directly.
Commit cleanly and report validation.
```
## Gates

Choose one ticket from the ready frontier in published dependency order. If the
frontier is empty while tickets remain, pause with the unresolved blockers.

Set `unit-base = HEAD`, run the selected route, and require an advancing commit,
required validation, and a clean environment. Diagnosis also requires one tight, red-capable command that reproduced the exact symptom, the supported cause,
cleanup, and a regression test at an approved seam. If no correct seam exists,
record that evidence and an `/improve-codebase-architecture` follow-up instead
of a shallow test.

Run `/code-review unit-base` once. Keep Standards and Spec separate. Zero on
both accepts the unit; a skipped Spec pauses the run. Otherwise, verify every
finding, then fix only confirmed findings from a captured `fix-base`.

After verification, set `best-burden` to the number of distinct open root causes.
A fresh closure checker checks the complete ledger and fix delta. Finish at zero.
A result below `best-burden` becomes the new best and continues; `best-burden` strictly decreases. Otherwise allow one recovery for that plateau.
A stalled behavioral defect uses `/diagnosing-bugs`; other roots get direct
correction. Recovery must fall below the unchanged `best-burden`; otherwise
pause with the same root cause evidence. There is no attempt counter. Do not rerun `/code-review` or rediscover the whole unit.

Reconcile the ticket's acceptance criteria, mark it complete through the
tracker, leave the parent Spec unchanged, and recompute the frontier. Continue
until the frozen queue is empty. After two or more tickets, apply the same
one-review and closure policy once to `run-base...HEAD` against the full Spec.

## Finish

Report the environment, branch, bases, final `HEAD`, ticket order, worker IDs,
commits, validation, review counts by axis, finding dispositions, tracker
updates, and unresolved evidence.
