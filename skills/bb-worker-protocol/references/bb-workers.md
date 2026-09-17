# BB worker protocol

One fresh visible worker thread per phase, parented to the orchestrator, one
at a time. Every phase gets its own BB thread so the run is watchable from
the IDE sidebar; the phase vocabulary is the `phase:` enum in
`worker-footer.md`. This
file is the single source for spawning, waiting on, inspecting, and verifying
one worker. Everything between turns — continuation, relay, pause, notify,
auto-resume, the `[watchdog]` tell — lives in `run-lifecycle.md`. The in-thread alternative in
`subagents.md` applies only when the user explicitly requests single-thread
execution; it is never the default.

Serial is the default because workers share one worktree. A skill may fan out
only workers that never write, such as an inventory or a navigation check, and
only when it verifies each one left `HEAD` and the tree unchanged. Anything that
commits stays serial.

Read flags from live help (`bb <group> --help`), never from memory. The `bb-cli`
skill's references cover anything this file does not, and `github.md` covers
every worker prompt that touches GitHub.

## Resolve context

```bash
bb status --json                          # .project.id, .thread.id, .childThreads
bb environment show "$ENV" --json         # .path, .branchName, .baseBranch, .managed
bb environment status "$ENV" --json       # working-tree state
bb machine list --json                    # .maxPermissionMode per host
bb provider list --json                   # provider IDs for --provider
bb provider models <provider> --json      # model IDs for --model
```

`BB_PROJECT_ID`, `BB_THREAD_ID`, `BB_ENVIRONMENT_ID`, and `BB_THREAD_STORAGE`
are set inside the orchestrator thread; prefer them over parsing `bb status`,
which has no top-level environment field and reports the ID at
`.thread.environment.display.id`. `.childThreads` lists this thread's workers,
which resume reconciles against the ledger.

Query providers and models on the machine that will run the worker: both
commands accept `--environment <id>` or `--machine <id-or-name>`.

## Spawn

Spawn every phase worker with `bb thread spawn`, so each appears as a child
thread in the IDE sidebar. Each phase gets its own new thread: spawn it, and
never fork or reuse a worker. Provider-native agent tools keep work inside this
thread: no BB child, no worktree isolation, no sidebar row. The first worker
of a ticket creates the managed worktree at the pinned base. Every later
worker of that ticket attaches to the same environment.

```bash
# first worker: new managed worktree at an exact ref (SHA, branch, origin/<branch>)
bb thread spawn --json --parent-self --project "$BB_PROJECT_ID" \
  --new-environment worktree --base-branch "$TICKET_BASE" \
  --visibility visible --title "<ticket-id> <phase>" \
  --file "$TICKET_FILE" --file "$FOOTER_FILE" \
  --prompt "$PROMPT"

# later workers: reuse the ticket environment
bb thread spawn --json --parent-self --project "$BB_PROJECT_ID" \
  --environment "$ENV" --visibility visible --title "<ticket-id> <phase>" \
  --file "$TICKET_FILE" --file "$FOOTER_FILE" --file "$FINDINGS_FILE" \
  --prompt "$PROMPT"
```

Title every worker `<ticket-id> <phase>` with the `phase:` vocabulary from
`worker-footer.md`, so the sidebar shows what each child is doing.
`--json` prints the thread record: read `.id` and `.environmentId`, then
`bb environment show` for the worktree path and branch name. Record all four
in the ledger before waiting. Confirm `.thread.visibility` is `visible` in
the spawn record; a worker the sidebar cannot see is a spawn bug, not a
worker to wait on.

Attach source files with `--file`; the prompt names them instead of restating
them. Always attach `worker-footer.md`, and close every prompt with the line
`End with the attached WORKER_RESULT footer.`
A slash command does not load a skill by itself, so attach the skill sources a
prompt relies on. Pass `--provider` and
`--model` from the ledger's `phases` map; omitted flags use project defaults.

Two ceilings bound a worker's permission mode: the orchestrator's own mode and
the host's `maxPermissionMode`. The server resolves a higher request down
silently, so a worker that cannot commit or push is a permission problem, not a
stall. Read the host ceiling from `bb machine list --json`; only the owner can
raise it, in Settings → Machines.

`--file` paths are read on the worker's machine, not the orchestrator's. For a
worker on another machine, upload once with `bb project attachment upload
"$BB_PROJECT_ID" --client-file <path>` and pass the returned relative path.

Spawn workers for immediate dispatch; `--send-at` is only for continuations
and resumes. Never pass it to a worker spawn: it creates a `pending` thread
with no environment and no worktree until the clock fires.

A new worker that stays `pending` may be held rather than stalled: the builtin
concurrency limit caps live threads per host at that host's parallelism.

```bash
bb thread queue list "$WORKER" --json   # .[].waitingOn.kind, .waitingOn.pluginId
bb concurrency-limit status --json      # effectiveLimit per host, when installed
```

A `waitingOn.kind: "plugin"` row is waiting. Wait again; never respawn.

## Wait

Listen; never poll. `bb thread wait` blocks server-side until the worker
reaches its target, so one call covers a whole phase no matter how long it
runs. The parent also receives lifecycle notifications when a child
completes, fails, or is interrupted (see `bb guide`): while the worker runs
there is nothing to fetch. Wakes and monitors are `bb thread wait`,
`bb thread show`, `bb thread list`, and `bb thread tell --send-at`.

```bash
bb thread wait "$WORKER" --timeout 1200 --json   # 0 idle, 2 timeout, 1 error
```

Exit 1 is not a slow worker: the ID is wrong, the thread was deleted, or the
server is unreachable. Never treat it as a timeout and wait again. Confirm the
ID against the ledger, then pause with `class: transient` when the server is
down and `class: decision` when the thread is gone.

A timeout means the worker is not idle yet; it is not a failed phase. On a
timeout, check only the things that can block silent progress:

```bash
bb thread show "$WORKER" --json                  # .thread.status, .thread.activeBackgroundAgentCount
bb thread interactions list "$WORKER" --json     # pending questions or approvals
bb thread list --parent-thread "$WORKER" --json  # nested BB children
```

- `status: error` gets one `bb thread retry "$WORKER"`; a second error pauses.
  Check `bb thread queue list "$WORKER" --json` first: the builtin Provider
  retry plugin already queues a retry when a turn fails on a subscription-window
  limit, and `bb thread retry` then fails with `retry_already_queued`. That
  queued row is the worker's one retry; count it and wait again.
- A pending interaction is handled before the next wait.
- Nested BB children that are not idle get `bb thread wait` each. A review
  worker's Standards and Spec children show up here.
- `.thread.activeBackgroundAgentCount > 0` after idle means in-thread agents
  are still running. Wait any BB children first; native handles use the
  provider wait tools in `subagents.md`. Do not parse the result yet.
- Otherwise wait again. Never read the worker log while waiting: one page
  stuffs hundreds of events into this thread and decides nothing. Never ask
  a working worker for status: the tell interrupts its turn and spends both
  threads' budget.
- Each timeout consumes 20 minutes of the ticket minutes budget; exhaustion
  pauses with `reason: budget`.
- A user stop on the orchestrator pauses at once.

Read-only fan-out is the exception to one-at-a-time: spawn the batch, then
wait each recorded ID. `bb thread list --parent-thread "$BB_THREAD_ID"` and
`bb status --json` `.childThreads` are the live set.

Never spawn the next worker before the current one is idle and inspected.

## Interactions

A worker with a pending interaction is waiting on a question or an approval and
makes no progress until it is resolved. A non-empty `interactions list` is the
signal; `bb thread show` does not carry one.

```bash
bb thread interactions list "$WORKER" --json
bb thread interactions show "$INTERACTION" "$WORKER" --json
bb thread interactions answer "$INTERACTION" "$WORKER" --choice <q>=<value> --text <q>="<text>"
bb thread interactions approve "$INTERACTION" "$WORKER"
bb thread interactions deny "$INTERACTION" "$WORKER"
```

Answer from the attached ticket or Spec when they settle the question. When
they do not, forward the question to the user verbatim and pause; on resume,
relay the user's answer with `interactions answer` and wait again. Approve
commands that validate, commit, or push inside the ticket worktree; deny or
forward everything else.

## Read the result

```bash
bb thread output "$WORKER" --json                # .output is the final message
```

Save the output under `$BB_THREAD_STORAGE` and parse the `WORKER_RESULT`
footer defined in `worker-footer.md`. A missing or malformed footer is
checked for a user stop before it is chased: `bb thread log "$WORKER"
--limit 1` ends with `Stopped manually` when the user stopped the worker,
and that pauses with `class: decision`, the worker ID, and the partial
output as evidence. Never respawn past a user stop; only the user resumes
it. Any other miss gets one `tell` asking for the footer; a second miss
pauses.

## Verify a mutating worker

The footer is a claim. Verify it before recording it. `bb thread show` reads
the worker's own workspace, so it holds whichever machine the worktree is on:

```bash
bb thread show "$WORKER" --json --work-status
# .workStatus.workingTree.hasUncommittedChanges == false
# .workStatus.checkout.headSha                  == footer.head
# .workStatus.mergeBase.aheadCount              >= 1
```

Read `hasUncommittedChanges`, not `workingTree.state`: a ticket branch with
commits reports `committed_unmerged`, never `clean`, so a state check fails
every real worker.

Then prove ancestry against the pinned SHA base and run validation yourself:

```bash
cd "$WORKTREE"
git status --porcelain                            # empty
git rev-parse HEAD                                # equals footer.head
git merge-base --is-ancestor "$BASE" HEAD         # base is an ancestor
git rev-list --count "$BASE"..HEAD                # at least 1 for a real change
<validation command from the ledger>              # exit 0
```

`workStatus.mergeBase` is computed against the environment's merge-base
*branch*, not the pinned `ticket-base` SHA, so it corroborates these checks and
never replaces them. When the worktree is on another machine, run validation in
that workspace and read the exit code from the session record:

```bash
TERMINAL=$(bb terminal create --environment "$ENV" --command "<validation>" --json | jq -r .id)
bb terminal wait "$TERMINAL" --exit --timeout 1800   # the default is 30 seconds
bb terminal show "$TERMINAL" --json                  # .exitCode must be 0
bb terminal output "$TERMINAL" --json                # the log, for the report
```

`wait` and `output` carry no exit code. Never record validation you did not
watch exit 0.

Reviewers and checkers leave `HEAD` and the tree exactly as they found them;
verify that too.

After a verified result that continues the run, release the worker's runtime:

```bash
bb thread stop "$WORKER"                 # thread and log remain
```

Do not archive it: archiving the last thread of a managed worktree destroys
the worktree. On pause, leave the worker as it is.

## Budgets

Each ledger carries `budget: { workers, minutes }`. Defaults: 12 workers and
360 minutes per ticket; 8 workers and 240 minutes for a standalone loop.
Spawning past either cap pauses with `reason: budget`. Budgets are safety caps;
the convergence rules in the skill decide when a loop is done.

Count workers from the ledger. Workers are visible, so `bb thread count`
and `bb thread list` see them. Both commands exclude hidden threads, so a
legacy run that left workers hidden needs `--include-hidden` on `list` to
see them, which `count` does not offer; the ledger stays authoritative
either way.

## Gotchas

- Archiving the last live thread of a *managed* worktree destroys the worktree
  and its local branch. `bb thread archive` also cascades to that thread's
  children and forks, so archiving a worker takes its `/code-review`
  subagents with it. Push first, and leave archiving to `land-stack`.
  `bb thread stop` releases the runtime without any of that.
- `--base-branch` is exact. Use a SHA for an accepted head and `origin/<branch>`
  for a remote ref.
- `tell` to a thread awaiting an interaction queues the message. That is not an
  error; do not resend. `.thread.queuedMessageCount` and `bb thread queue list`
  both show it.
