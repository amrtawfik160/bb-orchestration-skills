# Pull request stack

```text
main <- PR A <- PR B <- PR C
```

Each PR diff is one ticket. This file covers what happens after a PR opens:
checks, ready state, parent merges, rebases, and review comments.

## The CI baseline

Measure the target branch once, before the first ticket, and record it as
`ci_baseline`:

```bash
gh api "repos/{owner}/{repo}/commits/$TARGET/check-runs" --jq '[.check_runs[] | select(.conclusion == "failure") | .name]'
```

Record the names and the commit measured. A failure named here is
inherited, not caused, and never blocks this run. A repository whose default
branch is already red hands every PR the same failures; without this baseline
the run reads them as ticket failures and no PR ever becomes ready.

The `gh` commands below state what must be true at each step. Run them through
the `gh-axi` skill when it is installed, per the GitHub section of
`../../review-fix-loop/references/bb-workers.md`.

## The check sweep

CI outlives the turn that opened the PR, so checks are swept, never watched.
Open every turn by refreshing each `in_review` ticket's `pr.checks` and marking
ready whatever now passes net of `ci_baseline`. No PR stays recorded as
`pending`: a `pending` row in the ledger is work this turn owes, and the seven
stranded PRs that motivated this rule were all left `pending` by a turn that
moved on and never came back.

## After a PR opens

1. Verify the PR against the ledger:

   ```bash
   gh pr view "$URL" --json number,url,isDraft,baseRefName,headRefName,headRefOid
   bb environment pull-request show "$ENV" --json
   ```

   `headRefOid` equals the accepted head and `baseRefName` equals `pr_base`.
   Any mismatch pauses. BB tracks the same PR on the ticket environment, so
   its record and `gh` must agree; a disagreement means the ledger's
   environment or PR is wrong and pauses too.
2. Record the checks without blocking the turn on them:

   ```bash
   gh pr view "$URL" --json statusCheckRollup \
     --jq '[.statusCheckRollup[]? | {name: (.name // .context), state: (.conclusion // .state)}]'
   ```

   Never use `gh pr checks --watch` here. CI outlives the turn that opened the
   PR, so watching spends the turn that should be implementing the next ticket.
   An unfinished run records `checks: pending` and is resolved by the sweep at
   the start of a later turn, not left at `pending` forever.

   Compare every failure against `ci_baseline` before judging it:

   | Outcome | `pr.checks` | Action |
   |---|---|---|
   | No checks configured | `none` | Mark ready |
   | All green | `pass` | Mark ready |
   | Still running | `pending` | Sweep next turn |
   | Every failure is in `ci_baseline` | `baseline_fail` | Mark ready, report the inherited failures |
   | Any failure outside `ci_baseline` | `fail` | Pause: this one is the ticket's |

   A red target branch is the repository's problem, not this ticket's, and it
   must not strand the stack. Report inherited failures in Finish, and record a
   follow-up ticket for them rather than repairing them inside a ticket's diff.
   Mark a ready PR with `gh pr ready "$URL"`.
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
  both tickets. Spawn a fresh visible rebase worker in the child's environment:

  ```text
  Rebase <child-branch> onto origin/<target>, dropping the commits merged from <parent-branch>:
  git rebase --onto origin/<target> <parent-accepted-head> <child-branch>
  Resolve routine scope-preserving conflicts; pause only for an unresolved scope or user decision. Review changed semantics, validate, then push with --force-with-lease.
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

Equal IDs show patch equivalence, not a substitute for required validation.
Different IDs require inspecting the actual integrated diff: resolve routine
conflicts, rerun affected review and local gates, and record the new evidence.
Pause only when scope cannot be preserved or a decision belongs to the user;
never silently accept changes belonging to another ticket.

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
archives each ticket environment after its merge is confirmed. It runs the
parent-merge procedure above for every child before merging it.
