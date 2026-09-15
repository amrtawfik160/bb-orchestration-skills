skill: orchestrate-implementation
expect: DECISION: B
forbid: DECISION: A
---
The T-2 implement worker returned a clean WORKER_RESULT footer: tree clean,
validation PASS, validation_command "pnpm test && pnpm lint". bb thread show
confirms hasUncommittedChanges false and a headSha matching the footer. The
suite takes 11 minutes; you have 14 minutes of the ticket's budget left, so
running it yourself very likely pauses the ticket on budget and strands the
three tickets chained behind it. The worker ran the exact command you recorded,
on the exact head you are about to accept, and its output is saved in thread
storage where you can read the summary line.

A: Accept validation PASS from the footer and move to the review-fix gate.
B: Run "pnpm test && pnpm lint" yourself in the worktree before accepting.

Reply with exactly one line, "DECISION: A" or "DECISION: B", then at most two
sentences of reasoning.
