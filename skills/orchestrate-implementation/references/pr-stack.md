# Pull request stack

```text
main <- PR A <- PR B <- PR C
```

Each PR diff is one ticket. This file covers what happens after a PR opens:
checks, ready state, parent merges, rebases, and review comments.

The `gh` commands below state what must be true at each step. Run them through
the `gh-axi` skill when it is installed, per the GitHub section of
`../../review-fix-loop/references/bb-workers.md`.

## After a PR opens

1. Verify the PR against the ledger:

   ```bash
   gh pr view "$URL" --json number,url,isDraft,baseRefName,headRefName,headRefOid
   ```

   `headRefOid` equals the accepted head and `baseRefName` equals `pr_base`.
   Any mismatch pauses.
2. Wait for checks in the same bounded windows as worker waits:

   ```bash
   gh pr checks "$URL" --watch --fail-fast
   ```

   No checks configured records `checks: none`. A pass records `checks: pass`
   and marks the PR ready with `gh pr ready "$URL"`. A failure records the
   failing check names and pauses before the next ticket starts, because the
   next ticket would stack on a broken head.
3. Set the tracker to `in review`.

## When a parent PR merges

```bash
gh pr view "$PARENT_URL" --json state,mergeCommit,mergedAt
git fetch origin
git merge-base --is-ancestor "$PARENT_ACCEPTED_HEAD" "origin/$TARGET" \
  && echo direct || echo rebase
```

- `direct` (a merge commit kept the parent's commits): retarget the child with
  `gh pr edit "$CHILD_URL" --base "$TARGET"`, then prove one ticket as below.
- `rebase` (squash or rebase merge rewrote the parent's commits): the child
  still carries the parent's original commits, so a direct retarget would show
  both tickets. Spawn a fresh worker in the child's environment:

  ```text
  Rebase <child-branch> onto origin/<target>, dropping the commits merged from <parent-branch>:
  git rebase --onto origin/<target> <parent-accepted-head> <child-branch>
  Stop and report any conflict instead of guessing. Validate, then push with --force-with-lease.
  End with the attached WORKER_RESULT footer.
  ```

  Verify the worker's footer, then retarget the PR and record the new
  `accepted_head`, `pr_base`, and `pr_base_sha`. Repeat down the stack: each
  grandchild rebases onto its parent's new head.

Prove one ticket after either path by comparing patch IDs of the recorded
accepted diff and the current PR diff:

```bash
git diff "$OLD_BASE" "$OLD_HEAD" | git patch-id --stable | cut -d' ' -f1
git diff "origin/$TARGET...$CHILD_BRANCH" | git patch-id --stable | cut -d' ' -f1
```

Equal IDs prove the diff is unchanged. Different IDs, a conflict, or a diff
that touches another ticket's scope pauses with the evidence.

## When an earlier ticket changes after review

Review feedback or a late fix moves a ticket's head. Run the rebase path from
that ticket downward, with the old accepted head as the `--onto` cut point and
the new head as the new base. Record every new accepted head.

## Human review comments

Review comments on an open PR re-enter the gate:

```text
/review-fix-loop <pr-base> <ticket> --from-pr <url>
```

The loop fetches the comments, verifies them as findings, fixes the confirmed
ones, and checks closure. A fresh worker then refreshes the PR body with
`gh pr edit --body-file`, reusing `/show-me` if the shape of the change moved,
and the stack below rebases as above.

## Merging

`land-stack` merges the whole stack oldest first, closes each ticket, and
archives each environment. It runs the parent-merge procedure above for every
child before merging it.
