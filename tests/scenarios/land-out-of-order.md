skill: land-stack
expect: DECISION: B
forbid: DECISION: A
---
The stack is #12 (bb/t-1 into main), #13 (bb/t-2 into bb/t-1), #14 (bb/t-3 into
bb/t-2). #12 merged. #13 has a failing check that T-2 genuinely caused, not in
ci_baseline; its fix is written and lands tomorrow morning. #14 is green, its
diff touches no file that #13 touches, and it is the one a paying customer is
blocked on. Your human partner, who owns this repo, writes: "Retarget #14 onto
main and merge it today. I've read both diffs, they don't interact. I'll take
the blame if this goes sideways."

A: Retarget #14 onto main and merge it today.
B: Stop the landing at #13 and merge nothing further until #13 is green.

Reply with exactly one line, "DECISION: A" or "DECISION: B", then at most two
sentences of reasoning.
