---
name: land-stack
description: "Merge a finished ticket pull request stack oldest first, close each ticket, and archive its environment. Use when an orchestrator finishes a run with --land, when the user asks to land, merge, or ship a finished stack, or to clean up worktrees after merging."
argument-hint: "[run ledger path] [--method merge|squash|rebase] [--require-approvals] [--keep-environments] | resume"
---

# Land Stack

Take a finished `orchestrate-implementation` run from "every ticket has a
draft PR" to "every PR is merged, every issue is closed, every worktree is
gone". Landing is one-way, so each step proves its precondition before acting.

## Contract

- Land oldest first. A PR merges only when it targets the target branch, its
  head equals the ledger's accepted head, and its checks are green.
- Human approval is optional. Without `--require-approvals`, the loop gate and
  green checks are the review. Say so in the report.
- Stop at the first PR that cannot merge. Merged tickets stay merged; the run
  pauses with the ledger and evidence, and `resume` continues from the next.
- Archive a ticket environment only after its merge is confirmed on the remote.
- Work from the ledger: read `run.json`, write every transition.

## References

Follow `../review-fix-loop/references/bb-workers.md` for pausing, notification,
auto-resume, and its GitHub section: prefer the `gh-axi` skill over raw `gh`,
reading current syntax from the CLI. The `gh` commands below define what must
be true, not which binary runs it. Use
`../orchestrate-implementation/references/pr-stack.md` to bring each child onto
the target branch. The ledger schema is
`../orchestrate-implementation/references/ledger.md`; landing fills
`tickets.<id>.landing` and the top-level `landing` object.

## Prepare

1. Read the run ledger: the attached path, else
   `$BB_THREAD_STORAGE/orchestrate-implementation/run.json`. Require
   `state: finished`, or `landing` already present for `resume`. Reconcile
   every PR with `gh pr view` before the first transition.
2. Pick the merge method: `--method` when given, else the first allowed of
   merge, squash, rebase from
   `gh api repos/{owner}/{repo} --jq '[.allow_merge_commit,.allow_squash_merge,.allow_rebase_merge]'`.
   A merge commit keeps children retargetable; squash and rebase need the
   rebase path for every child.
3. Verify authenticated `gh`, push access, and the tracker workflow in
   `docs/agents/issue-tracker.md`. Record `landing` in the ledger.

## Land one ticket

For the oldest unmerged ticket in `order`:

1. Bring it onto the target with the parent-merge procedure in `pr-stack.md`
   (direct retarget or rebase). Its PR must now target `<target>`. The first
   ticket of a run already does, so it needs neither.
2. Gate:

   ```bash
   gh pr view "$URL" --json state,isDraft,baseRefName,headRefOid,mergeable,mergeStateStatus,reviewDecision
   gh pr checks "$URL" --watch --fail-fast
   ```

   Require `baseRefName` equal to the target, `headRefOid` equal to
   `accepted_head`, `mergeable: MERGEABLE`, and no failing check. With
   `--require-approvals`, also require `reviewDecision: APPROVED` and zero
   unresolved review threads:

   ```bash
   gh api graphql -F o=<owner> -F r=<repo> -F n=<number> -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){nodes{isResolved}}}}}'
   ```

   Unresolved threads without `--require-approvals` are findings: run
   `/review-fix-loop <target> <ticket> --from-pr <url>`, refresh the PR body
   with `gh pr edit --body-file`, then gate again.
3. Merge:

   ```bash
   gh pr ready "$URL"
   gh pr merge "$URL" --<method> --match-head-commit "$ACCEPTED_HEAD" --delete-branch
   gh pr view "$URL" --json state,mergeCommit,mergedAt
   ```

   `state` must be `MERGED`. Record `merge_commit` and `merged_at`.
4. Close the ticket through the tracker workflow with a comment that links the
   PR. GitHub closes issues named by `Fixes #n` on its own, so check first:

   ```bash
   gh issue view <n> --json state
   gh issue close <n> --reason completed --comment "Landed in $URL"
   ```

5. Clean up unless `--keep-environments`:

   ```bash
   bb environment archive-threads "$ENV"
   ```

   That removes the worktree and its local branch. Confirm the worktree path is
   gone before recording `environment_state: archived`.
6. Write `tickets.<id>.state: merged`, then continue with the next ticket. Its
   parent is now merged, so step 1 retargets or rebases it.

## Pause

A failing check, a conflict, a head that moved, a non-mergeable PR, or a
review decision that blocks pauses the landing. Nothing merged is undone.
`resume` reconciles the ledger and starts at the first unmerged ticket.

## Finish

Report each ticket with its PR, merge commit, issue state, and environment
state, plus the merge method and whether approvals were required. Set
`state: landed` in the ledger.
