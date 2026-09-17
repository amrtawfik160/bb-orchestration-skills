---
name: codebase-docs-cleanup
description: "Clean a codebase using Matt Pocock's code-first documentation approach: audit or prune redundant docs, slim AGENTS.md and CLAUDE.md, and make code easier for agents to navigate. Use for an explicit code-first cleanup request, not routine feature work."
argument-hint: "<repo path or subsystem> [--audit] [--apply] | resume | status"
---

# Code-first cleanup

Make the implementation the source of truth for current behavior. Make code
discoverable and understandable instead of maintaining a prose mirror of it.
Preserve what code cannot explain: decisions and rejected alternatives, domain
meaning, and a thin navigation layer.

This is a documentation and code-readability cleanup, not permission to delete
arbitrary source files, redesign the product, or change behavior.

## Contract

- Work in one managed BB worktree at a pinned base. The source checkout is never
  touched; discarding the branch reverts the run.
- Inventory and navigation workers are read-only and run in parallel; they leave
  `HEAD` and the tree exactly as they found them. Every mutating batch is one
  serial worker, verified before the next one starts.
- The orchestrator owns the plan, the ledger, and validation. A worker's table
  or claim is evidence to check in the worktree, never a decision.
- Audit stops after the plan. Apply needs an explicit request to clean the
  repository.
- No deletion quota, target file count, or line limit. Success is less competing
  context carrying the same useful knowledge and behavior.
- Every inventory, batch, and navigation check shares the cleanup worktree.

## References

Follow `../bb-worker-protocol/references/bb-workers.md` for spawning, waiting,
interactions, result parsing, verification, and budgets, and
`../bb-worker-protocol/references/run-lifecycle.md` for what happens between
turns. Attach
`../bb-worker-protocol/references/worker-footer.md` to every worker.
`references/inventory.md` owns the classification, evidence, and decision
rules used during Inventory and Plan. `references/pruning.md` owns the
readability and prose rules each cleanup batch applies.
Keep the ledger in `references/ledger.md`.

## Modes

`--audit` produces findings and a plan without edits; a request for an
assessment alone is an audit. `--apply`, or an explicit request to clean the
repository, authorizes scoped edits. `status` prints the ledger and takes no
action. `resume` reconciles the ledger with BB and Git, then continues from the
next batch.

## Prepare

1. Resolve the repository from the user's path or `bb status --json`. Pause and
   ask when more than one project stays plausible.
2. Read the repository's own instructions, including nested ones covering paths
   in scope. Record Git status and any existing diff; unrelated and pre-existing
   edits survive this run untouched.
3. Pin `cleanup-base` at the current committed `HEAD` and create the managed
   worktree there. A fresh worktree checks out tracked files only, so list the
   source checkout's untracked material with
   `git ls-files --others --exclude-standard`, record it as out of scope, and
   say so in the report. This run never deletes a file it cannot see.
4. Limit the first pass to first-party source, tests, configuration, and
   documentation. Vendored files, dependencies, generated output, submodules,
   and external directories are separate scope.
5. Resolve and record `validation` per
   `../bb-worker-protocol/references/validation.md`, reading it from real
   scripts, configuration, and CI. Run it once at `cleanup-base` for the
   baseline, including its known failures and any unavailable dependency.
   A failure already in the baseline is never evidence against a later batch.
6. Write the ledger and arm the `[watchdog]` tell from `run-lifecycle.md`.
   Do not reset, force-clean, push, or open a pull request unless separately
   requested.

## Inventory

Partition the repository by subsystem and spawn one read-only worker per
partition into the same environment, each in its own visible BB thread. They
run concurrently because they only
read. Discover partitions from the tree, never from the docs:

```bash
bb environment paths "$ENV" --directories --limit 100 --json
```

Verify each worker left `HEAD` and the tree unchanged, then merge its table into
the ledger. Deduplicate by path and heading, record coverage per partition
rather than implying a sample was exhaustive, and resolve any item two
partitions classified differently before planning. An unpartitioned repository
gets one worker.

## Plan

Build one short ordered plan from the merged inventory with the decision rules
in `references/inventory.md`. Each batch names exact target paths, the intended
benefit, the knowledge to preserve with its destination, and the validation to
run. Separate uncertain and high-impact changes from safe work.

Write the plan and inventory under `$BB_THREAD_STORAGE/codebase-docs-cleanup/`
and open them with `bb thread open <path>`. In audit mode, stop here. Never
create a permanent cleanup report inside the repository unless the user asks.

## Worker prompts

`references/worker-prompts.md` holds the inventory, cleanup batch, and
cold-start prompts.

## Gates

A batch may run only when every deletion in it has a verified reason and a named
destination for the unique knowledge it carries. Take the readability branch
only where the inventory found a concrete navigation problem, and never as a
whole-repository reformat, dependency update, or architecture migration.

After each batch, verify the worker in the worktree and run `validation`
yourself. A new failure against the baseline reverts that batch and pauses;
never carry one into the next. Keep uncertain facts unchanged and flag them, and
never invent decision history, alternatives, or definitions to fill a gap.

A contradiction between documentation and verified behavior is a finding, not a
cleanup target: report it and leave the requirement standing rather than
deleting the requirement to make the conflict disappear.

## Verify

Review the whole diff from BB, deletions included, rather than from memory:

```bash
bb environment diff-files "$ENV" --target branch_committed --merge-base-branch "$BASE_BRANCH" --json
bb environment diff-patch "$ENV" --target branch_committed --merge-base-branch "$BASE_BRANCH" --path <deleted-path> --json
```

Account for every planned item as completed, retained, deferred, or blocked, and
resolve every reference to a moved or deleted path along with the remaining
navigation targets and anchors.

Then prove the navigation layer with cold-start workers, one per representative
subsystem, each in a fresh visible BB thread. A fresh thread has no memory of this cleanup, which is the only
honest test of an entry document. A worker that has to guess, or that reaches
for a narrative this run removed, is a failing pointer and not a failing worker:
fix the pointer, then spawn a new worker to recheck it.

Run the documentation and code checks for the changed scope, compare them with
the recorded baseline, and distinguish a pass from a skipped check and from a
pre-existing failure. Confirm that unique rationale, domain definitions,
operational requirements, and project constraints survived, then recheck Git
status in both the worktree and the source checkout.

## Rationalizations

| Excuse | Reality |
|---|---|
| "This doc is stale, the code says otherwise — delete it" | A contradiction is a finding. Report it; do not delete the requirement to make the conflict disappear. |
| "Nothing unique in this file, it's all in the code" | Prove it by naming where. A deletion needs a verified reason *and* a named destination for what it carried. |
| "While I'm here, this module could be restructured" | Documentation and readability only. Not a refactor, dependency update, or architecture migration. |
| "The cold-start worker got confused, spawn a smarter one" | A worker that has to guess is a failing pointer, not a failing worker. Fix the pointer, then recheck with a new worker. |
| "Validation failed, but it was probably already failing" | Compare against the recorded baseline. "Probably" is how a cleanup ships a regression. |
| "Inventory workers are read-only, so fan out the batches too" | Batches commit. Anything that writes stays serial and verified before the next one starts. |
| "A big deletion count proves it worked" | There is no quota. Success is less competing context carrying the same knowledge. |

## Red flags — stop

- About to delete a file whose unique knowledge has no named destination
- About to run two mutating batches at once
- About to carry a new validation failure into the next batch
- About to reformat, upgrade, or restructure code the inventory did not flag
- About to apply edits when the user only asked for an assessment

## Finish

Report in plain language: what was removed or simplified, what was preserved and
why, readability changes, validation against the baseline, untracked material
left out of scope, and every unresolved item with its smallest next step.
Include a compact path and action summary, and claim only counts you measured.

End with the branch, worktree path, and environment. The branch is left for the
user: `/review-fix-loop <cleanup-base>` gates it before a pull request, and
discarding it reverts the run.
