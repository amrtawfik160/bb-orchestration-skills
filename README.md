# bb orchestration skills

[![Install from skills.sh](https://img.shields.io/badge/skills.sh-install-111827?style=flat-square)](https://skills.sh/amrtawfik160/bb-orchestration-skills)

These skills run [Matt Pocock's agent skills](https://github.com/mattpocock/skills)
inside BB. They coordinate his `/to-spec`, `/to-tickets`, `/implement`, `/tdd`,
and `/code-review` flow, and route hard defect tickets through
`/diagnosing-bugs`. Matt's skills still do the underlying work.

Tickets run serially. Each ticket gets its own branch, managed worktree,
review-fix gate, and pull request. Each worker gets one job in a fresh thread
with access only to that ticket's worktree. During review, Matt's `/code-review`
starts its required independent Standards and Spec subagents.

The orchestrator runs `review-fix-loop` directly. That skill starts the fresh
review, verification, and fix workers, so there is no nested coordinator.

Each gate runs one full review. A fresh worker treats each finding as a
hypothesis and checks its cited evidence before fixing it. Afterward, another
fresh worker confirms that each finding is closed and reviews the fix delta for
regressions. The workflow does not rerun `/code-review` to chase a zero-finding
result. The `/code-review` guide warns that repeated reviews are
nondeterministic and may not converge.

Once every ticket is accepted, `land-stack` merges the pull requests oldest
first, closes the tickets, and removes the worktrees.

![One ticket to one PR to merged, one BB worker at a time. Per ticket: a fresh branch and worktree, implement or diagnose, one review across Standards and Spec, then a draft PR whose checks must go green before it is marked ready. Findings go through verify, fix, and a closure check before reaching the PR. The next ticket starts from the accepted head. At the end, land-stack merges the stack oldest first, closes each ticket, and removes each worktree.](assets/bb-orchestration-workflow-v6.png)

## Skills

### `orchestrate-implementation`

Processes an approved ticket graph one ticket at a time, following its blocker
frontier. Planned work and known fixes use `/implement`; hard, unexplained,
intermittent, and performance defects use `/diagnosing-bugs`. Each ticket is
reviewed, its confirmed findings are fixed, and one draft PR is pushed before
the next ticket starts in a new environment. Later PRs stack on the previous
ticket branch, so each PR keeps a one-ticket diff.

The PR worker opens the draft PR itself with `gh` and builds the body from
`/show-me`: the smallest diagram, call tree, or diff shape that shows what the
ticket changed, plus two sentences of context.

### `review-fix-loop`

Starts from an existing committed diff. It runs one two-axis review from a
pinned base, fixes confirmed findings, and verifies that they are closed. With
`--from-pr <url>` it takes pull request review comments as the finding source
instead of running a new review.

### `land-stack`

Ends the run. It merges the PR stack oldest first, closes each ticket, and
archives each ticket environment, which removes its worktree and branch. Every
PR is gated on green checks and a head that still matches the reviewed one, and
each child is retargeted or rebased onto the target branch before it merges.
Landing stops at the first PR that cannot merge; whatever already merged stays
merged, and `resume` picks up at the next ticket.

Approval is optional. By default the loop gate and green checks are the review,
so the whole path from tickets to merged main runs without you. Pass
`--require-approvals` to also require an approving review and no unresolved
comment threads. Unresolved comments without that flag are treated as findings
and go back through the fix loop.

### `show-me`

Vendored from [humanlayer/skills](https://github.com/humanlayer/skills) under
the MIT license. It explains a topic with concise diagrams, code-shape
sketches, and Mermaid. The orchestrator hands it to the PR worker; you can also
invoke it directly.

## Reference files

The skills stay short because the mechanics live in reference files:

| File | Owns |
|------|------|
| `review-fix-loop/references/bb-workers.md` | Exact `bb` commands to spawn, wait on, inspect, and verify workers; interactions; GitHub access; budgets; pausing, notification, and auto-resume |
| `review-fix-loop/references/worker-footer.md` | The `WORKER_RESULT` footer every worker ends with, attached to each spawn |
| `review-fix-loop/references/ledger.md` | Loop ledger schema under `$BB_THREAD_STORAGE` |
| `orchestrate-implementation/references/ledger.md` | Run ledger schema, including per-phase provider and model choices and landing state |
| `orchestrate-implementation/references/pr-stack.md` | Checks, ready state, squash-merge rebases, review comments, merge order |
| `orchestrate-implementation/references/recovery.md` | Rebuilding a stack from an older single-branch run |

## What they enforce

- One active worker at a time.
- A fresh BB thread for every implementation, diagnosis, review, finding check,
  fix, and closure check.
- One branch and managed worktree per ticket; only that ticket's workers share
  it.
- Worker claims are verified in the worktree: clean tree, expected `HEAD`, and
  the resolved validation command rerun by the orchestrator.
- One draft PR per accepted ticket, with the issue left open until merge. The
  PR is marked ready when its checks pass; a failing check pauses before the
  next ticket stacks on it.
- A linear PR stack that lets work continue without cumulative PR diffs, and a
  rebase procedure that keeps each child at one ticket after a squash merge.
- Cross-ticket integration only when `/to-tickets` provides an explicit
  integration ticket; there is no implicit final mega-PR.
- Every ticket in the frozen blocker graph, with missing edges, cycles, and
  tickets without acceptance criteria rejected before implementation.
- A clean managed worktree when the source checkout has unrelated changes.
- Matt's separate Standards and Spec reviewers, with a guard against recursive
  agent spawning.
- One full review per gate, followed by targeted evidence and closure checks.
  Fix cycles that continue to make progress run until no root cause remains; if
  a cycle stalls, it gets one focused recovery before the run pauses.
- Worker and wall-clock budgets per ticket and per loop as safety caps.
- A resumable ledger, and a defined pause: state written, evidence reported,
  nothing torn down. Worker questions the ticket cannot answer are forwarded to
  you and relayed back on resume.
- Every pause classified. Rate limits and other transient stalls clear
  themselves through a scheduled resume; only real decisions reach you, with the
  command that continues the run.
- Merges in stack order, with cleanup gated on a merge confirmed at the remote.
- One approved tracer-bullet ticket per implementation or diagnosis thread,
  with the parent Spec left unchanged.
- Small worker prompts that invoke Matt's skills and attach source material.

## Why serial

Independent tickets could run in parallel worktrees, but the linear PR stack
depends on each ticket branching from the previous accepted head. Parallel
tickets would each branch from the target and need a merge step to reconcile,
which is the cumulative integration this workflow avoids. Serial order also
keeps one review gate and one validation run per ticket.

## Requirements

- `bb` on `PATH` and a BB project thread.
- The `bb-cli` skill.
- The bundled `review-fix-loop`, `land-stack`, and `show-me` skills when using
  `orchestrate-implementation`.
- [Matt Pocock's skills](https://github.com/mattpocock/skills), including
  `implement`, `diagnosing-bugs`, `tdd`, and `code-review`.
- `/to-spec` and `/to-tickets` when using the full planning flow.
- Authenticated `gh` and push access to the repository. The
  [`gh-axi`](https://github.com/kunchenguid/gh-axi) skill is preferred over raw
  `gh` when installed; it wraps the same auth in a lower-token CLI. Install it
  with `npx skills add kunchenguid/gh-axi --skill gh-axi -g`.
- A configured issue tracker through `/setup-matt-pocock-skills`.

`/to-spec`, `/to-tickets`, `/implement`, and `/ask-matt` are user-invoked.
The orchestrator consumes approved planning artifacts and gives each spawned BB
thread its own slash-command prompt. It does not model-invoke those skills in
its own context. `/ask-matt` remains a router, not a workflow step.

## Install

Install from skills.sh. `review-fix-loop` and `show-me` work on their own;
the orchestrator needs all four:

```bash
npx skills add amrtawfik160/bb-orchestration-skills
```

Start the orchestrator in a new BB environment after installing or updating.
BB pins skill revisions when an environment loads, so an open environment keeps
using its previous revision.

Or copy them into BB's user skill directory, which is `skills/` inside the bb
data directory. That is `~/.bb/skills` by default; `bb status` prints the data
directory this server actually uses.

```bash
git clone https://github.com/amrtawfik160/bb-orchestration-skills.git
mkdir -p ~/.bb/skills
cp -R bb-orchestration-skills/skills/* ~/.bb/skills/
```

Two skills read reference files from their siblings' directories, so install
them together:

- `orchestrate-implementation` reads `../review-fix-loop/references/`.
- `land-stack` reads both `../review-fix-loop/references/` and
  `../orchestrate-implementation/references/`.

`review-fix-loop` and `show-me` have no such dependency.

## Usage

The unattended path is one command:

```text
/orchestrate-implementation <spec or ordered ticket references> --land
```

That implements every ticket, reviews and fixes each one, opens the PR stack,
merges it oldest first, closes the tickets, and removes the worktrees. It stops
only for a decision it cannot make.

The individual entry points:

```text
/orchestrate-implementation <spec or ordered ticket references>
/orchestrate-implementation resume
/orchestrate-implementation status
/land-stack [run ledger path] [--method merge|squash|rebase] [--require-approvals] [--keep-environments]
/land-stack resume
/review-fix-loop <fixed-point> [spec or ticket reference] [--from-pr <url>]
/show-me
```

## Tests

```bash
bash tests/run.sh
```

Ten scripts run. Most check the skill contracts. Three go further:

- `bb-commands.sh` verifies that every `bb` command and flag in the worker
  protocol exists in the installed CLI, so the docs cannot drift from it.
- `pr-stack-rebase.sh` runs the documented squash-merge rebase against a
  temporary Git repository and proves each child PR still holds one ticket.
- `land-stack-order.sh` runs the documented landing sequence against stubbed
  `gh` and `bb`, proving PRs merge oldest first, that an environment is
  archived only after its merge is confirmed, and that a failing check stops
  the run without touching the rest of the stack.

## License

MIT. The bundled `show-me` skill keeps its own MIT license from HumanLayer in
`skills/show-me/LICENSE`.
