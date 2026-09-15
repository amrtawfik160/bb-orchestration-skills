# One run, end to end

A three-ticket run with the real values at each gate. Read this once to see
how `ticket-base`, `pr-base`, the footer, the ledger, and `LOOP_GATE` line up;
the rule files stay authoritative.

Graph: `T-1 → T-2 → T-3`. Target `main` at `a1b2c3d`. Validation
`pnpm test && pnpm lint`.

## T-1: the first ticket branches from the target

```
ticket_base   a1b2c3d   (main, pinned as a SHA, not "main")
pr_base       main
ticket_branch bb/t-1
```

Spawn the implement worker. It is the ticket's first worker, so it creates the
worktree:

```bash
bb thread spawn --json --parent-self --project "$BB_PROJECT_ID" \
  --new-environment worktree --base-branch a1b2c3d \
  --visibility visible --title "T-1 implement" \
  --file /path/tickets/T-1.md --file /path/worker-footer.md \
  --prompt "$PROMPT"
```

`--json` returns `.id: thr_w1a`, `.environmentId: env_t1`. Record both, plus
the worktree path and branch from `bb environment show env_t1 --json`, then
`bb thread wait thr_w1a --timeout 1200 --json`.

It comes back with:

```yaml
WORKER_RESULT:
  phase: implement
  status: DONE
  base: a1b2c3d
  head: e4f5a6b
  tree: clean
  validation: PASS
  validation_command: "pnpm test && pnpm lint"
```

That is a claim. Verify it:

```bash
bb thread show thr_w1a --json --work-status
#   .workStatus.workingTree.hasUncommittedChanges  false
#   .workStatus.checkout.headSha                   e4f5a6b   == footer.head
cd "$WORKTREE"
git merge-base --is-ancestor a1b2c3d HEAD     # exit 0
git rev-list --count a1b2c3d..HEAD            # 3
pnpm test && pnpm lint                        # exit 0 — yours, not the worker's
```

Then `bb thread stop thr_w1a`. Never `bb thread archive`: env_t1 is managed,
and archiving its last thread deletes the worktree.

## The review-fix gate runs at `ticket-base`

`review-fix-loop` applies in the orchestrator, at `review-base = a1b2c3d`. Its
own fresh threads do review, finding check, fix, closure check. It returns:

```yaml
LOOP_GATE:
  verdict: PASS
  review_base: a1b2c3d
  final_head: 7c8d9e0
  open_confirmed_findings: 0
```

Write that whole block to `tickets.T-1.loop.gate`. An unwritten gate is a
skipped gate: `state: finished` alone never says which axes ran.

`accepted_head` is now `7c8d9e0` — the loop's `final_head`, not the
implementer's `e4f5a6b`. The fix commits are part of the ticket.

## The PR

A fresh PR worker pushes `bb/t-1` and opens the draft PR. Verify its remote
head equals `7c8d9e0` and its base is `main` before recording
`https://github.com/org/repo/pull/12`. Then per `pr-stack.md`: record checks,
mark ready once they pass net of `ci_baseline`, set the tracker to `in review`.

The ticket stays open. Implementation and review passing is not a merge.

## T-2 chains from T-1's accepted head

```
ticket_base   7c8d9e0        (T-1's accepted head, exactly)
pr_base       bb/t-1         (so PR #13 diffs only T-2)
ticket_branch bb/t-2
```

New worktree at `7c8d9e0`, same cycle. T-3 chains from T-2's accepted head
with `pr_base: bb/t-2`. Three tickets, three PRs, each a one-ticket diff:

```
#12  bb/t-1 → main
#13  bb/t-2 → bb/t-1
#14  bb/t-3 → bb/t-2
```

There is no fourth integration PR. Cross-ticket integration is its own
approved ticket or it does not happen.

## Finish

```
LANDABLE: yes
```

Three accepted tickets, three green PRs. `land-stack` merges #12 first, then
retargets #13 onto `main` per `pr-stack.md`, and so on. A red check on #13
instead gives:

```
LANDABLE: no, https://github.com/org/repo/pull/13 checks failing: Typecheck
```

— unless `Typecheck` is in `ci_baseline`, in which case it was already red on
`main` at `a1b2c3d`, the PR is inherited-red, and the run reports it and
continues.
