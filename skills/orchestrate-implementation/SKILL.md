---
name: orchestrate-implementation
description: "Use when an approved spec or ticket set should run serially in fresh BB threads, with one review and closure of confirmed findings."
argument-hint: "<spec, ticket set, or ticket references>"
disable-model-invocation: true
---

# Orchestrate Implementation

Run approved work from Matt Pocock's planning flow:

```text
ready ticket -> implement -> review once -> accept -> close ticket -> next
                                      -> verify findings -> fix -> verify closure
all tickets -> one integration review -> finish
```

`/to-spec` and `/to-tickets` are user-invoked planning skills. Consume their
approved artifacts; do not recreate or triage their tickets.

## Contract

- Keep orchestration serial: one orchestrator-spawned BB worker is active at a
  time. `/code-review` may create its required Standards and Spec subagents;
  those subagents create no descendants.
- Spawn a fresh thread for every implementation, review, finding check, fix,
  and closure check. Reuse one cumulative environment and never fork.
- Implement one full ticket reference per run. Tickets from `/to-tickets` are
  already sized for one fresh context. If a bare Spec needs several sessions,
  pause and ask the user to run `/to-tickets`.
- Pin `run-base` and each `unit-base`. Implementation and fixes commit and
  leave a clean tree; reviews and checks leave `HEAD` and the tree unchanged.
- Push, PR, merge, deploy, archive, and cleanup require separate requests.

## Prepare

1. Use `bb-cli` to resolve the project, provider, environment, branch, clean
   committed `HEAD`, tracker configuration, full Spec, tickets, and blockers.
   The parent Spec is context, not an implementation unit.
2. Snapshot the resolved artifacts once and attach the same files to every
   relevant worker. Under `$BB_THREAD_STORAGE`, record bases, worker IDs,
   states, and finding dispositions after each transition. On resume, reconcile
   that ledger with BB and Git before taking one next transition.
3. Reuse a clean environment or create one managed worktree at `run-base`.
   Leave unrelated source-checkout changes untouched.
4. Verify `bb-cli`, `implement`, `tdd`, and `code-review` for the selected
   provider and environment. Spawn with explicit project, parent, environment,
   provider, attachments, and JSON output.

## Wait for workers

Use `bb thread wait <id> --timeout 1200 --json`. A timeout means the worker is
not idle yet; it is not a failed phase. Compare work status, latest event
sequence, interactions, and Git state. Progress starts another wait. After two
unchanged windows, inspect the log and pending interactions, then send one
`tell` asking for status. One more unchanged window pauses the run. A user stop
or pending question pauses immediately. Never spawn the next worker before the
current one is idle and inspected.

## Worker prompts

Attach sources instead of pasting or restating them.

Implementation:

```text
/implement <full ticket or spec reference>
Skip its same-session review; commit cleanly for a fresh reviewer.
```

Review:

```text
/code-review <base>
Spec: <attached spec or ticket>.
Add to both axis briefs: "Do not invoke /code-review or spawn additional agents; perform this review directly."
Keep the worktree unchanged.
```

Finding check:

```text
Verify each attached finding against its cited source and <base>...HEAD.
Assign <axis>-<n> IDs; return CONFIRMED or DISPUTED with evidence. Keep the worktree unchanged.
```

Fix:

```text
Fix only the attached confirmed findings.
Use /tdd for behavioral fixes only at attached pre-agreed seams. Commit cleanly and report validation.
```

Closure check:

```text
Check each attached confirmed finding against <base>...HEAD after the fix.
Return RESOLVED or OPEN with evidence; keep the worktree unchanged.
```

## Gates

Set `unit-base = HEAD`, run `/implement`, and require an advancing commit,
passing validation, and a clean environment.

Run `/code-review unit-base` once. Keep its Standards and Spec reports separate;
do not replace them with a blended verdict. If both axes report zero findings,
accept the unit. If Spec was skipped, pause rather than claim a two-axis pass.

Treat review output as hypotheses. A fresh finding-check worker verifies every
citation. If none are confirmed, accept the unit with that evidence. Otherwise,
fix only confirmed findings. Before each fix, capture `fix-base = HEAD`; a real
fix must advance from it.

After a fix, use a fresh closure checker instead of rerunning `/code-review`.
Matt's review is nondeterministic and is not a convergence loop. Finish the
gate when no confirmed finding remains OPEN. Allow at most two fix attempts;
then pause with the evidence.

After accepting a ticket, reconcile its criteria, mark it complete through the
configured tracker, leave the parent Spec unchanged, and recompute the blocker
frontier. After multiple tickets, apply the same one-review policy once to
`run-base...HEAD` against the full Spec.

## Finish

Report the environment, branch, bases, final `HEAD`, worker IDs, commits,
validation, per-axis review counts, finding dispositions, ticket updates, and
any unresolved evidence.
