---
name: review-fix-loop
description: "Review and fix a committed diff in fresh BB threads, stopping safely when findings stop converging."
argument-hint: "<fixed-point> [spec or ticket reference]"
disable-model-invocation: true
---

# Review Fix Loop

Orchestrate one serial loop:

```text
review -> pass -> finish
       -> fix -> re-review
       -> non-converging -> diagnose -> pause
```

Use `bb-cli`, `code-review`, `implement`, `tdd`, and `diagnosing-bugs` for their
own procedures. This skill supplies only BB coordination and convergence gates.

## Rules

- Keep one worker active at most. Every review, fix, re-review, and diagnosis
  gets a fresh spawned thread in one cumulative environment.
- BB pins skill revisions per environment. Start the orchestrator in a new
  environment after installing or updating this skill.
- Spawn; never fork or reuse. Workers work alone and create no descendants or
  background work.
- Pin one review-base. Reviews are read-only; fixes are committed, validated,
  and clean. A dirty run environment pauses.
- Before review, split a diff above 25 changed files or 2,000 changed lines
  unless the user explicitly keeps it whole.
- Push, PR, merge, deploy, archive, and cleanup are separate requests.

## Prepare

1. Resolve the project, provider, branch, `initial-head`, fixed point, Spec,
   standards, and tracker configuration. Pin
   `review-base = merge-base(fixed-point, initial-head)` and require a non-empty
   committed diff.
2. Freeze mutable inputs as hashed BB attachments outside the repository. Use
   committed bytes for clean committed inputs.
3. Reuse a clean source environment. Otherwise create one managed worktree
   from `initial-head`, excluding source-checkout dirt. Require a committed
   baseline for code included in the review.
4. Verify required skills in the chosen provider and run environment, then
   record a resumable ledger under `$BB_THREAD_STORAGE`.

Before every spawn, require the prior worker to be idle. Waiting is bounded
observation: use `bb thread wait <id> --timeout 60 --json`. After each timeout,
record a **heartbeat** from status, latest event sequence, interactions, Git
state, descendants, and background work. Any change resets the stale count.

Five consecutive timeouts without a heartbeat is a stall. Inspect show,
output, the paged log, interactions, and topology. Honor a user stop or pending
question. Otherwise send one corrective `tell`; if the next sample is
unchanged, pause and report. If the user asked only to wait, do not `tell`,
stop, or spawn. Pause and report the stall. Do not issue another wait until the
user resumes.

After each worker, inspect its report, Git state, and topology. Reject a phase
that violated the rules.

## Worker prompts

Attach sources; never paste their contents or restate a skill.

Review:

```text
/code-review <base> <spec>
Work alone; run Standards then Spec sequentially; create no descendants.
Keep the tree unchanged. End with stable finding IDs and REVIEW_GATE.
```

On re-review, add only:

```text
Verify the attached findings first, then review the whole diff. Reuse IDs when
the root cause repeats. Mark unrelated improvements FOLLOW_UP.
```

Fix:

```text
/implement
Fix the attached findings with `/tdd` where useful. Work alone; create no descendants.
Stop before built-in review. Commit, leave clean, and report validation.
```

Diagnosis:

```text
/diagnosing-bugs
Explain why the attached finding history is not converging. Work alone; make no changes.
Recommend the smallest next unit of work.
```

## Gates

Every review covers `review-base...HEAD`, stays read-only, and ends with:

```yaml
REVIEW_GATE:
  standards_findings: <integer>
  spec_findings: <integer>
  total_findings: <integer>
  verdict: PASS|CHANGES_REQUESTED
```

Verify each cited rule or requirement before fixing it. Track unrelated scope
as a ticket labeled `FOLLOW_UP`; do not count it as a blocking finding.

For a fix, capture `fix-base = HEAD`. Accepted findings must produce a commit
with `fix-base` as ancestor; all-disputed findings must leave `HEAD` unchanged
and include evidence. Every fix gets a fresh holistic review from the original
review-base.

At most three review attempts are allowed. Compare normalized root causes, not
wording or counts; key each by axis, citation, code locus, and failure. Spawn
one fresh diagnosis worker when a root cause repeats, two consecutive reviews
do not reduce blocking findings, or the third review still has findings. After
diagnosis, pause and report; diagnosis does not reset the review budget.

Finish only after a fresh review reports zero Standards and zero Spec findings.

## Finish

Report the environment, branch, review-base, initial and final `HEAD`, ordered
worker IDs, fix commits, validations, review count, final gate, follow-ups, and
any diagnosis.
