# bb orchestration skills

[![Install from skills.sh](https://img.shields.io/badge/skills.sh-install-111827?style=flat-square)](https://skills.sh/amrtawfik160/bb-orchestration-skills)

These skills are built for [Matt Pocock's agent skills](https://github.com/mattpocock/skills).
They orchestrate his `/to-spec`, `/to-tickets`, `/implement`, `/tdd`, and
`/code-review` flow inside BB. They do not replace those skills.

The BB workflow stays serial: one worker gets one job, then hands the shared
worktree to a fresh thread. Matt's `/code-review` is the sole exception inside
that worker; it uses its required independent Standards and Spec subagents.

Each gate runs one holistic review. Its findings are hypotheses, so a fresh
worker verifies their citations before a fixer acts. Another fresh worker then
checks that every confirmed finding is closed. The workflow does not rerun
`/code-review` until it happens to return zero; its own guide warns that repeated
reviews are nondeterministic and do not promise convergence.

![BB orchestration workflow: implement, review once, verify findings, fix, and verify closure in fresh threads sharing one worktree.](assets/bb-orchestration-workflow-v2.png)

## Skills

### `orchestrate-implementation`

Takes a spec or ordered tickets. It implements one unit at a time, reviews it,
fixes confirmed findings, updates the ticket, and runs one final integration
review after a multi-ticket build.

### `review-fix-loop`

Starts with an existing committed diff. It runs one two-axis review from a
pinned base, fixes confirmed findings, and verifies their closure.

## What they enforce

- One active worker at a time.
- A fresh BB thread for every implementation, review, finding check, fix, and
  closure check.
- One shared worktree, so accepted commits remain visible to later workers.
- A clean managed worktree when the source checkout has unrelated changes.
- Matt's separate Standards and Spec reviewers, with a guard against recursive
  agent spawning.
- One holistic review per gate, followed by targeted evidence and closure
  checks. At most two fix attempts are allowed.
- One approved tracer-bullet ticket per `/implement` thread, with the parent
  Spec left unchanged.
- Small worker prompts that invoke Matt's skills and attach source material.

## Requirements

- `bb` on `PATH` and a BB project thread.
- The `bb-cli` skill.
- [Matt Pocock's skills](https://github.com/mattpocock/skills), including
  `implement`, `tdd`, and `code-review`.
- `/to-spec` and `/to-tickets` when using the full planning flow.
- A configured issue tracker through `/setup-matt-pocock-skills`.

`/to-spec`, `/to-tickets`, `/implement`, and `/ask-matt` are user-invoked.
The orchestrator consumes approved planning artifacts and gives each spawned BB
thread its own slash-command prompt; it does not model-invoke those skills in
the orchestrator's context. `/ask-matt` remains a router, not a workflow step.

## Install

Install from skills.sh and choose one or both skills:

```bash
npx skills add amrtawfik160/bb-orchestration-skills
```

Start the orchestrator in a new BB environment after installing or updating.
BB pins skill revisions when an environment loads, so an already-open
environment continues using its previous revision.

Or copy them into BB's default user skill directory:

```bash
git clone https://github.com/amrtawfik160/bb-orchestration-skills.git
mkdir -p ~/.bb/skills
cp -R bb-orchestration-skills/skills/* ~/.bb/skills/
```

## Use

```text
/orchestrate-implementation <spec or ordered ticket references>
/review-fix-loop <fixed-point> [spec or ticket reference]
```

## License

MIT
