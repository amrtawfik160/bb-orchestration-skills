# Worker prompts

One job per worker, in a fresh visible BB thread. Attach source files with
`--file` and name them in the prompt instead of restating them. A slash
command does not load a skill by itself, so attach the relevant skill sources.
Every prompt ends with `End with the attached WORKER_RESULT footer.`

Implementation:
```text
/implement <attached full ticket>
Use the ticket's seams, or the project's documented test seams. Validate, commit, and leave the tree clean. End before /code-review.
```

Diagnosis:
```text
/diagnosing-bugs
Fix the attached ticket through all six phases. Validate, commit, and leave the tree clean.
```

Pull request:
```text
Push exact clean HEAD, then open a draft PR from <ticket-branch> into <pr-base> for <ticket> with `gh pr create --draft`, or gh-axi if installed. Title it from the ticket summary.
For the body use /show-me: the smallest diagram, call tree, or diff shape that shows what this ticket changed, plus two sentences of context. No HTML file.
Return its URL and base/head SHAs.
```

The loop's phase prompts belong to
`review-fix-loop`, which this orchestrator applies directly. The rebase prompt
is in `pr-stack.md`.

Keep the task brief tight: move detailed source material into attached
files. A worker that never saw the run must be able to execute from the
brief plus attachments alone.
