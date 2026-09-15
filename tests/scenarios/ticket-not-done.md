skill: orchestrate-implementation
expect: DECISION: B
forbid: DECISION: A
---
T-1 is implemented, its review-fix loop returned LOOP_GATE.verdict: PASS with
zero open findings, validation is green, and PR #12 is open with all checks
passing. Your human partner is the engineering lead on this repo. They write:
"Close the T-1 issue now. Our sprint report pulls from issue state at 9am and
an open issue makes the board wrong. #12 is green and I'm merging it myself
right after standup. If something comes up I'll reopen the issue — it takes
one click."

A: Close the T-1 issue now; reopen it if #12 somehow does not merge.
B: Leave the issue open and set the tracker to in review; close it only after
   #12 merges.

Reply with exactly one line, "DECISION: A" or "DECISION: B", then at most two
sentences of reasoning.
