---
name: review-fix-loop
description: "Review and fix a committed diff through fresh BB workers. Use when an orchestrator needs a code-review gate before opening a pull request, when the user invokes the loop directly, or when pull request review comments must be verified and fixed."
argument-hint: "<fixed-point> [spec or ticket reference] [--from-pr <url>]"
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
  thread in one ticket environment. Never fork or reuse a worker.
- Pin one immutable review base. Reviews and checks are read-only; fixes commit,
  validate, and leave the tree clean. Verify every claim in the worktree.
- Return a clean gate to the caller. The caller owns branch push and PR creation;
  merge, deploy, archive, and cleanup remain separate actions.

## References

Follow `references/bb-workers.md` for spawning, waiting, interactions, result
parsing, verification, budgets, and pausing. Attach
`references/worker-footer.md` to every worker. Keep the ledger described in
`references/ledger.md`.

## Prepare

1. Use `bb-cli` to resolve the project, provider, environment, branch,
   `initial-head`, fixed point, Spec, standards, and tracker configuration.
   Require a clean committed diff and pin
   `review-base = merge-base(fixed-point, initial-head)`.
2. Resolve `validation`: the ticket's own validation line, else the project's
   documented check, else the package's `test`, `lint`, and `typecheck`
   scripts. Record the command and run it yourself after every fix.
3. Snapshot the Spec or ticket once for every worker. Write the ledger after
   each transition; on resume, reconcile it with BB and Git before taking one.
4. Reuse a clean environment or create one managed worktree at `initial-head`,
   leaving unrelated source-checkout changes untouched. Verify `bb-cli`,
   `tdd`, and `code-review` for the selected provider and environment.

If no Spec exists, get the user's approval for a Standards-only run before
spawning. Report Spec as skipped; never call that a two-axis pass. With
`--from-pr <url>`, or attached findings, skip the review worker: fetch the PR
review comments with `gh api`, save them as the finding source, and start at
the finding check.

## Worker prompts

Attach sources instead of pasting or restating them. Every prompt ends with
`End with the attached WORKER_RESULT footer.`

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
Consolidate the same root cause under one stable <axis>-<n> ID; return CONFIRMED or DISPUTED with evidence. Keep the worktree unchanged.
```

Fix:

```text
Fix only the attached confirmed findings.
Use /tdd for behavioral fixes only at attached pre-agreed seams. Commit cleanly and report validation.
```

Closure check:

```text
Check the complete attached finding ledger and <fix-base>...HEAD. Reuse IDs for the same root cause. Return RESOLVED or OPEN; label only regressions caused by the fix CONFIRMED_FIX_REGRESSION.
Keep the worktree unchanged.
```

Recovery:

```text
Recover the attached stalled root causes. For a stalled behavioral defect use /diagnosing-bugs and its tight red loop; otherwise correct the cited root directly.
Commit cleanly and report validation.
```

## Gates

Run `/code-review review-base` once. Preserve its separate Standards and Spec
reports. If both axes report zero findings, finish. For an approved
Standards-only run, finish only when Standards reports zero and keep Spec
explicitly skipped.

Otherwise, use a fresh finding checker to verify every citation. Fix only
confirmed findings. If none are confirmed, finish with that evidence. Before
each fix, capture `fix-base = HEAD`; a real fix advances from it and passes
`validation` when the orchestrator runs it.

After verification, set `best-burden` to the number of distinct open root causes.
A fresh closure checker checks the complete ledger and fix delta. Finish at zero.
A result below `best-burden` becomes the new best and continues; `best-burden` strictly decreases. Otherwise allow one recovery for that plateau.
A stalled behavioral defect uses `/diagnosing-bugs`; other roots get direct
correction. Recovery must fall below the unchanged `best-burden`; otherwise
pause with the same root cause evidence. There is no attempt counter; only the
worker budget caps a loop that keeps converging. Do not rerun `/code-review`:
it is nondeterministic and does not promise convergence.

## Finish

End with:

```yaml
LOOP_GATE:
  verdict: PASS | PASS_STANDARDS_ONLY | PAUSED
  review_base: <sha>
  final_head: <sha>
  open_confirmed_findings: <count>
```

`PASS` requires both axes and zero open confirmed findings. Report the ticket
environment, branch, worker IDs, fix commits, validation, finding dispositions,
and unresolved evidence before the footer.
