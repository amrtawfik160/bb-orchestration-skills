---
name: review-fix-loop
description: "Use when a committed diff needs one fresh BB code review, fixes for confirmed findings, and bounded closure verification."
argument-hint: "<fixed-point> [spec or ticket reference]"
disable-model-invocation: true
---

# Review Fix Loop

```text
review once -> no findings -> finish
            -> findings -> verify -> fix -> verify closure -> finish or pause
```

## Contract

- Keep one orchestrator-spawned BB worker active. `/code-review` may create its
  required Standards and Spec subagents; those subagents create no descendants.
- Give every review, finding check, fix, and closure check a fresh spawned
  thread in one cumulative environment. Never fork or reuse a worker.
- Pin one immutable review base. Reviews and checks are read-only; fixes commit,
  validate, and leave the tree clean.
- Push, PR, merge, deploy, archive, and cleanup require separate requests.

## Prepare

1. Use `bb-cli` to resolve the project, provider, environment, branch,
   `initial-head`, fixed point, Spec, standards, and tracker configuration.
   Require a clean committed diff and pin
   `review-base = merge-base(fixed-point, initial-head)`.
2. Snapshot the Spec or ticket once for every worker. Under
   `$BB_THREAD_STORAGE`, record bases, worker IDs, states, and finding
   dispositions after each transition. On resume, reconcile that ledger with
   BB and Git before taking one next transition.
3. Reuse a clean environment or create one managed worktree at `initial-head`,
   leaving unrelated source-checkout changes untouched.
4. Verify `bb-cli`, `tdd`, and `code-review` for the selected provider and
   environment. Spawn with explicit project, parent, environment, provider,
   attachments, and JSON output.

If no Spec exists, get the user's approval for a Standards-only run before
spawning. Report Spec as skipped; never call that a two-axis pass.

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

Review:

```text
/code-review <base>
Spec: <attached spec or ticket; omit for approved Standards-only>.
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

Run `/code-review review-base` once. Preserve its separate Standards and Spec
reports. If both axes report zero findings, finish. For an approved
Standards-only run, finish only when Standards reports zero and keep Spec
explicitly skipped.

Otherwise, use a fresh finding checker to verify every citation. Fix only
confirmed findings. If none are confirmed, finish with that evidence. Before
each fix, capture `fix-base = HEAD`; a real fix advances from it.

Use a fresh closure checker after each fix. Do not rerun `/code-review` to
chase a clean report: the skill is nondeterministic and does not promise
convergence. Finish when no confirmed finding remains OPEN. Allow at most two
fix attempts, then pause with the evidence.

## Finish

Report the environment, branch, review base, initial and final `HEAD`, worker
IDs, fix commits, validation, per-axis review counts, finding dispositions, and
any unresolved evidence.
