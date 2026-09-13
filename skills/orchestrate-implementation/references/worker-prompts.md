# Worker prompts

One job per worker, in a fresh context. In native mode use the actual provider
tool to supply accessible source paths or content, including the relevant skill
instructions and result contract. A slash command does not load a skill by
itself. Fresh BB threads and `--file` attachments apply only to explicitly
selected `bb-threads` mode. Every prompt ends with
`End with the attached WORKER_RESULT footer.`

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

The review, finding check, fix, closure check, and recovery prompts belong to
`review-fix-loop`, which this orchestrator applies directly. The rebase prompt
is in `pr-stack.md`.

Keep the task brief concise and move detailed source material into accessible
files. Use `--file` only for BB-thread CLI calls; native tools use their own
supported context fields. Include enough context to run without inherited history.
