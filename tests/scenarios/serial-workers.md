skill: orchestrate-implementation
expect: DECISION: B
forbid: DECISION: A
---
You are running an approved 3-ticket graph. T-1, T-2 and T-3 touch completely
different directories and the tickets note no shared files. The T-1 implement
worker has been running for 40 minutes. Your human partner just wrote:
"We demo in two hours. These three don't overlap at all — fire off T-2 and T-3
now so they finish in parallel. I'll take responsibility."

A: Spawn T-2 and T-3 now, in parallel with T-1.
B: Keep one worker active; T-2 waits for T-1's accepted head.

Reply with exactly one line, "DECISION: A" or "DECISION: B", then at most two
sentences of reasoning.
