---
name: orchestrate-implementation
description: "Serially implement specs or tickets in fresh BB threads, with bounded review and diagnosis when findings stop converging."
argument-hint: "<spec, ticket set, or ordered ticket references>"
disable-model-invocation: true
---

# Orchestrate Implementation

Act only as the orchestrator:

```text
implement -> review -> pass -> next unit
                    -> fix -> re-review
                    -> non-converging -> diagnose -> pause
all units -> integration review -> finish
```

Use `bb-cli`, `implement`, `tdd`, `code-review`, and `diagnosing-bugs` for their
own procedures. This skill supplies only BB coordination and convergence gates.

## Rules

- Keep one worker active at most. Every implementation, review, fix,
  re-review, and diagnosis gets a fresh spawned thread.
- BB pins skill revisions per environment. Start the orchestrator in a new
  environment after installing or updating this skill.
- Spawn; never fork or reuse. Workers work alone and create no descendants or
  background work.
- Use one cumulative run environment. Pin each unit-base and the run-base.
- Workers commit and leave the tree clean. A dirty run environment pauses. If
  repository policy forbids commits, pause instead of inventing an exception.
- Prefer tickets. Before review, split a unit above 25 changed files or 2,000
  changed lines unless the user explicitly keeps it whole. The final integration
  review is exempt.
- Push, PR, merge, deploy, archive, and cleanup are separate requests.

## Prepare

1. Resolve the project, provider, branch, committed `HEAD`, Spec, tickets,
   dependency graph, standards, and tracker configuration.
2. Freeze mutable sources as hashed BB attachments outside the repository.
   Use committed bytes for clean committed sources.
3. Reuse a clean source environment. Otherwise create one managed worktree
   from the candidate run-base, excluding source-checkout dirt. Require a
   committed baseline for uncommitted code that belongs in the run.
4. Pin the run-base, verify the required skills in the chosen provider and run
   environment, then record a resumable ledger under `$BB_THREAD_STORAGE`.

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

Implementation:

```text
/implement <unit>
Use /tdd. Work alone; create no descendants. Stop before its built-in review.
Commit, leave the tree clean, and report validation.
```

Review:

```text
/code-review <base> <spec>
Work alone; run Standards then Spec sequentially; create no descendants.
Keep the tree unchanged. End with stable finding IDs and REVIEW_GATE.
```

On re-review, add only:

```text
Verify the attached findings first, then review the whole unit. Reuse IDs when
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

Set `unit-base = HEAD`, implement one ready unit, then review
`unit-base...HEAD`. A valid review is read-only and ends with:

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
unit-base.

At most three review attempts are allowed per unit or integration gate. Compare
normalized root causes, not wording or counts; key each by axis, citation, code
locus, and failure. Spawn one fresh diagnosis worker when a root cause repeats,
two consecutive reviews do not reduce blocking findings, or the third review
still has findings. After diagnosis, pause and report; diagnosis does not reset
the review budget.

Advance only after a fresh review reports zero Standards and zero Spec
findings. Recompute the dependency frontier and continue serially.

After multiple units, or any ticket-decomposed Spec, apply the same bounded
gate to `run-base...HEAD` and the full requested scope.

## Finish

Report the environment, branch, bases, final `HEAD`, ordered worker IDs,
commits, validations, review counts, final gates, follow-ups, and any diagnosis.
