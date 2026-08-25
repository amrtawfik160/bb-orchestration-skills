---
name: orchestrate-implementation
description: "Implement a spec or ordered tickets serially in fresh BB threads, fixing and re-reviewing each unit until Standards and Spec both report zero."
argument-hint: "<spec, ticket set, or ordered ticket references>"
disable-model-invocation: true
---

# Orchestrate Implementation

Act only as the orchestrator:

```text
implement unit -> review (Standards -> Spec)
                    | findings -> fix -> fresh review
                    | 0 + 0 ----> next unit
all units --------------------------------> integration review -> finish
```

Use `bb-cli`, `implement`, `tdd`, and `code-review` for their rubrics, with the
serial rules below.

## Rules

- Keep one worker active at most. Every implementation, review, fix, and
  re-review gets a fresh spawned thread parented to this orchestrator.
- Never fork or reuse a worker. Workers act directly: no subagents, delegation,
  worker-created threads, or background agents.
- Use one cumulative run environment. Do not create a worktree per ticket.
- Pin each unit-base for all reviews of that unit; pin the run-base for the
  integration review.
- One reviewer performs Standards first and Spec second, sequentially. This
  overrides `code-review`'s parallel step.
- Advance only on a fresh `0 Standards / 0 Spec` review.
- Workers commit locally, but do not push, open or merge PRs, deploy, archive,
  or clean up unless separately asked.

## Prepare

1. Inspect BB and Git state. Capture the project, host, provider, branch,
   source environment, and committed `HEAD` as the candidate run-base.
2. Resolve the input from the argument or the immediately preceding `/to-spec`
   or `/to-tickets`. Read the configured issue tracker; if missing, request
   `/setup-matt-pocock-skills`.
3. Prefer tickets as units when they exist. Read every ticket and its
   `Blocked by` edges, reject an invalid graph, and choose one ready ticket at a
   time in tracker order. Use a whole spec as one unit only when it has no
   tickets or the user explicitly asks. Do not triage `/to-tickets` output.
4. Freeze the exact spec, tickets, standards, tracker configuration, and agent
   instructions. Use committed bytes for clean committed inputs; snapshot and
   hash mutable inputs as BB attachments outside the repo.
5. Reuse the source environment only when clean. Otherwise let the first
   implementation create one managed BB worktree from the candidate run-base,
   leaving source changes untouched. If uncommitted code belongs in the run,
   require a committed baseline.
6. Recheck branch and `HEAD`, pin the run-base, and require the run environment
   to start there clean. Pin one provider and verify `bb-cli`, `implement`,
   `tdd`, and `code-review` are available.

Keep a ledger under `$BB_THREAD_STORAGE` with frozen inputs, graph, environment,
run/unit bases, phase, workers, commits, validations, findings, and gates.
Reconcile it with BB and Git on resume.

Before each spawn, require the previous worker to be idle. After it finishes,
inspect its output, Git state, and BB topology. Accept it only if it ran alone
and left no descendants or background work. A timeout keeps waiting; an
intentional user stop pauses the run.

## Run each unit

### Implement

Set `unit-base = HEAD` and spawn a fresh implementation thread with the full
unit, acceptance criteria, relevant parent-spec context, completed blockers,
frozen inputs, and expected starting SHA.

It follows `/implement` and `/tdd`, but skips `/implement`'s built-in review;
review belongs to the next fresh thread. Require a committed implementation,
clean tree, targeted checks, full relevant suite, and exact validation report.
Accept only if it started at `unit-base`, advanced `HEAD` with that base still
its ancestor, and all checks passed. Report a stale/no-op unit instead of
fabricating a commit.

### Review

Capture `review-start = HEAD` and spawn a fresh read-only reviewer against
`unit-base...HEAD`. For a ticket, its acceptance criteria are the Spec scope;
the parent spec is context. For a direct spec unit, the full spec is scope.
Require findings with IDs, axes, locations, evidence, and fixes, followed by:

```yaml
REVIEW_GATE:
  standards_findings: <integer>
  spec_findings: <integer>
  total_findings: <integer>
  verdict: PASS|CHANGES_REQUESTED
```

Counts must match the findings and their sum. Accept only if `HEAD` still
equals `review-start`, the tree is clean, and the worker rules held. Restore
only attributable uncommitted reviewer edits, discard that report, and review
fresh. A staged or committed review pauses the run; do not rewrite history.

### Fix

For findings, capture `fix-base = HEAD` and spawn a fresh fixer with the full
review and unit sources. It addresses every finding, uses `/tdd` where
appropriate, validates, and leaves the tree clean.

- Any accepted finding requires a fix commit after `fix-base`, which remains
  its ancestor.
- If all findings are disputed, require `HEAD = fix-base` and evidence for each.

Re-review in a fresh thread from the original unit-base, without the previous
verdict. Repeat until `0`, `0`, `0`, `PASS`. Persisting findings become
diagnosis work for the next fresh fixer; never waive them or impose a retry
limit while safe progress remains.

### Advance

After the zero gate, record accepted `HEAD`, mark the unit complete, recompute
the dependency frontier, and choose one next ready unit. Accepted `HEAD`
becomes its unit-base.

## Integrate and finish

After multiple units, or whenever a spec was decomposed into tickets, run the
same fresh review/fix loop over `run-base...HEAD` and the complete requested
scope. Keep the run-base fixed until a fresh integration review reports
`0`, `0`, `0`, `PASS`.

Report the run environment and branch, run-base and final `HEAD`, units and
worker IDs in order, implementation and fix commits, validations, loop counts,
final gates, and excluded source changes.
