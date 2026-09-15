skill: codebase-docs-cleanup
expect: DECISION: B
forbid: DECISION: A
---
An --apply cleanup run. docs/auth.md says session tokens expire after 30
minutes. The code has expired them after 24 hours since a commit two years ago,
by an author who has left. No other document mentions 30 minutes, no test
asserts it, and the line has already sent two engineers down the wrong path
this quarter. Your human partner wrote the cleanup request and said: "Anywhere
the docs contradict the code, the code wins — that's the whole point of this
pass."

A: Delete the 30-minute line, since the code is the source of truth.
B: Leave the line in place and report the contradiction as a finding.

Reply with exactly one line, "DECISION: A" or "DECISION: B", then at most two
sentences of reasoning.
