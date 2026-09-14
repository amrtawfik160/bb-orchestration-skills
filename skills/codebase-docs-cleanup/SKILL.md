---
name: codebase-docs-cleanup
description: "Clean a codebase with in-thread sub-agents using Matt Pocock's code-first documentation approach: audit or prune redundant docs, slim AGENTS.md and CLAUDE.md, preserve decisions and domain knowledge, and make code easier for agents to navigate. Use for an explicit code-first cleanup request, not routine feature work."
argument-hint: "<repo path or subsystem> [--audit] [--apply] | resume | status"
---

# Code-first cleanup

Read `../review-fix-loop/references/subagents.md` first. Default to native sub-agents
in this BB thread and one shared checkout; use its direct fallback if needed.
That protocol overrides worker/workspace/relay/cleanup instructions below;
BB-thread operations apply only to explicitly selected `bb-threads` mode.
Keep all ticket, review, validation, and PR gates in either mode.


Make the implementation the source of truth for current behavior. Make code
discoverable and understandable instead of maintaining a prose mirror of it.
Preserve what code cannot explain: decisions and rejected alternatives, domain
meaning, and a thin navigation layer.

This is a documentation and code-readability cleanup, not permission to delete
arbitrary source files, redesign the product, or change behavior.

## Contract

- Work in one recorded checkout at a pinned base. Reuse the current checkout
  in sub-agent mode and preserve pre-existing edits. Creating a managed
  worktree is an explicit BB-thread-mode operation, subject to user scope.
- Inventory and navigation workers are read-only and run in parallel; they leave
  `HEAD` and the tree exactly as they found them. Every mutating batch is one
  serial worker, verified before the next one starts.
- The orchestrator owns the plan, the ledger, and validation. A worker's table
  or claim is evidence to check in the worktree, never a decision.
- Audit stops after the plan. Apply needs an explicit request to clean the
  repository.
- No deletion quota, target file count, or line limit. Success is less competing
  context carrying the same useful knowledge and behavior.

In explicit `bb-threads` mode, use one managed BB worktree at a pinned base.
The source checkout is never touched; discarding the branch reverts that
isolated run. This does not permit deleting the persistent native-mode checkout.

## References

Follow `../review-fix-loop/references/bb-workers.md` for spawning, waiting,
interactions, result parsing, verification, budgets, pausing, and notification,
and attach `../review-fix-loop/references/worker-footer.md` to every worker.
`references/inventory.md` owns classification, evidence, and the decision rules.
`references/pruning.md` owns the readability and prose rules that workers apply.
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
5. Resolve `validation` from real scripts, configuration, and CI. Run it once at
   `cleanup-base` and record the result, its known failures, and any unavailable
   dependency as the baseline.
   A failure already in the baseline is never evidence against a later batch.
6. Write the ledger. Do not reset, force-clean, push, or open a pull request
   unless separately requested.

## Inventory

Partition the repository by subsystem and spawn one read-only worker per
partition into the same environment. They run concurrently because they only
read. Discover partitions from the tree, never from the docs:

```bash
bb environment paths "$ENV" --query "" --directories --limit 100 --json
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

Every prompt ends with `End with the attached WORKER_RESULT footer.`

Inventory:

```text
Inventory <partition> for a code-first documentation cleanup.
Read the implementation before judging its documentation: start at entry points, public contracts, domain types, tests, and configuration, then follow imports into representative paths.
Classify every candidate file and independently actionable section with the attached rules, citing source, test, or config paths and inbound references as evidence. Read a file's full relevant content before proposing to delete it, and search for inbound links, imports, doc-build inputs, and tooling references first.
Keep the worktree unchanged. Return the table and the coverage you actually reached.
```

Cleanup batch:

```text
Apply the attached batch only, following the attached pruning and readability rules.
Write the knowledge it names to the destination it names before removing the source, and update incoming links and doc-build references in the same batch.
Preserve public APIs, serialized shapes, routes, persisted schemas, configuration semantics, and initialization order. Add focused characterization tests before changing poorly covered behavior; defer instead of asserting equivalence you cannot check.
Validate, commit, and leave the tree clean.
```

Cold-start navigation:

```text
You have not seen this repository before. Start only from <entry document> and read only what it and its pointers lead you to.
For <subsystem>, locate the implementation and its tests. Report the exact path sequence you followed and every point where you had to guess or search outside those pointers.
Keep the worktree unchanged.
```

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
subsystem. A fresh thread has no memory of this cleanup, which is the only
honest test of an entry document. A worker that has to guess, or that reaches
for a narrative this run removed, is a failing pointer and not a failing worker:
fix the pointer, then spawn a new worker to recheck it.

Run the documentation and code checks for the changed scope, compare them with
the recorded baseline, and distinguish a pass from a skipped check and from a
pre-existing failure. Confirm that unique rationale, domain definitions,
operational requirements, and project constraints survived, then recheck Git
status in both the worktree and the source checkout.

## Finish

Report in plain language: what was removed or simplified, what was preserved and
why, readability changes, validation against the baseline, untracked material
left out of scope, and every unresolved item with its smallest next step.
Include a compact path and action summary, and claim only counts you measured.

End with the branch, worktree path, and environment. The branch is left for the
user: `/review-fix-loop <cleanup-base>` gates it before a pull request, and
discarding it reverts the run.
