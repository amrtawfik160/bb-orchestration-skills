# Run lifecycle

How a run survives longer than one turn: queueing its own continuation,
handing off before context runs out, pausing, telling the user, and the
`[watchdog]` tell that re-arms a run nobody woke. `bb-workers.md` owns
everything inside a single worker; this file owns everything between turns.

## Continue the run

A run outlives one turn. Ending a turn is not pausing: a turn that stops with
work left and nothing queued leaves the run waiting for a human who does not
know it is waiting.

A turn may end only in a terminal state — `finished`, `landed`, `audited`, or
`paused` with `class: decision` — or with exactly one continuation queued.
Queue it as the turn ends, not as it starts: every queued row renders in the
IDE Queue panel, so a row queued at turn start sits as a `Queue 1` badge for
the whole turn. An interrupted or errored turn with nothing queued is covered
by the `[watchdog]` tell below, which re-arms this thread if it goes idle
with an empty queue while the ledger is still `running`.

`--mode queue` holds the message on `waitingOn.kind: "thread-busy"` and
dispatches it when the current turn ends. Use the exact template for the
running skill, so the row names its ledger instead of an anonymous ask:

```bash
# orchestrate-implementation (ledger: $BB_THREAD_STORAGE/orchestrate-implementation/run.json)
bb thread tell "$BB_THREAD_ID" '[continuation] orchestrate-implementation: read run.json and take the next transition. If state is finished, landed, or paused, end the turn silently without re-queueing.' --mode queue --json

# land-stack (ledger: the run.json path landing was given)
bb thread tell "$BB_THREAD_ID" '[continuation] land-stack: read run.json and land the next unmerged ticket. If state is landed or paused, end the turn silently without re-queueing.' --mode queue --json

# verify-landing (ledger: the run.json path verification was given)
bb thread tell "$BB_THREAD_ID" '[continuation] verify-landing: read run.json and verify the next unverified merge. If verification is verified or paused, end the turn silently without re-queueing.' --mode queue --json

# review-fix-loop standalone (ledger: $BB_THREAD_STORAGE/review-fix-loop/<base7>.json)
bb thread tell "$BB_THREAD_ID" '[continuation] review-fix-loop: read the loop ledger and take the next transition. If state is finished or paused, end the turn silently without re-queueing.' --mode queue --json

# codebase-docs-cleanup (ledger: $BB_THREAD_STORAGE/codebase-docs-cleanup/run.json)
bb thread tell "$BB_THREAD_ID" '[continuation] codebase-docs-cleanup: read run.json and take the next transition. If state is audited, finished, or paused, end the turn silently without re-queueing.' --mode queue --json
```

Before queueing, delete any continuation rows already on the thread, so wakes
never stack. Match the `[continuation]` prefix and the legacy generic text:

```bash
bb thread queue list "$BB_THREAD_ID" --json \
  | jq -r '.[] | select(.content[].text | test("^\\[continuation\\]|^\\[watchdog\\]|^Continue this run from its ledger")) | .id' \
  | while read -r row; do bb thread queue delete "$BB_THREAD_ID" "$row"; done
```

Record the queued row's id as `notify.continuation_message` where the ledger
tracks one, and delete the row when the turn reaches a terminal state. On
wake, read the ledger first: a terminal or paused state ends the turn
silently after clearing stale continuation rows, never with a fresh queue.

A brief `[continuation]` row between turns is normal: it auto-dispatches at
turn end and is safe to ignore. Deleting it only delays the run until the
`[watchdog]` tell fires, within ten minutes. Say so in one line when the user
asks about the Queue row; never present it as needing their action.

A turn ends when it has nothing left to do, never because it is waiting.
Never end a turn while a worker is active: block on it inside the turn with
`bb thread wait` in a loop, as in Wait. When the only pending item is CI on a
PR, queue the orchestrate template as a scheduled row instead of an immediate
one, so the run wakes every ten minutes instead of every few seconds:

```bash
bb thread tell "$BB_THREAD_ID" '[continuation] orchestrate-implementation: read run.json and take the next transition. If state is finished, landed, or paused, end the turn silently without re-queueing.' --send-at 10m --json
```

One orchestrator that skipped both rules completed a turn every 25 seconds for
hours, each turn re-sweeping one PR and re-queueing itself.

Every continuation that does work records a ledger transition, and an
unchanged sweep is not a transition. Two consecutive continuations with no
transition and nothing pending (no active worker, no PR at `checks: pending`)
pause the run with `class: decision` and `reason: no_progress`. A continuation
past the run budget pauses with `reason: budget`. Both caps exist because a
queued continuation is a loop.

## Relay to a successor

One thread cannot hold a long run. Relay applies to runs whose ledger tracks
`relay`: orchestrate-implementation, codebase-docs-cleanup, and land-stack
and verify-landing via the shared run ledger. Standalone review-fix-loop
gates use continuation for turn hops instead. Read your own context usage
before starting another ticket or batch. Prefer the free probe; fall back
to the log only when it reports null:

```bash
bb thread context --self --json                   # .usage; null when unrecorded
bb thread log --self --format json --all | jq -r '[.[] | select(.type == "thread/contextWindowUsage/updated")] | last | .data.contextWindowUsage | "\(.usedTokens)/\(.modelContextWindow)"'
```

Past 70% of the model window, finish the unit of work in flight, hand the
run to a fresh orchestrator, record its ID as `relay.successor`, tell the user
which thread continues the run, and stop:

```bash
bb thread spawn --json --project "$BB_PROJECT_ID" --visibility visible \
  --title "<run> continued" --file "$LEDGER" --prompt "$CONTINUE_PROMPT"
```

Use this exact handoff prompt, with the skill and ledger path filled in:

```text
Continue this <skill> run from the attached ledger: save it to your own
$BB_THREAD_STORAGE/<skill-path>, record this thread as relay.predecessor,
reconcile it with BB, Git, GitHub, and the tracker, then take the next
transition per the skill. The ledger is the whole handoff; inherit no timeline.
```

The successor saves the ledger first and arms its own continuation and
`[watchdog]` tell. A successor with no ledger cannot continue.
Never fork for this: a fork inherits the context that ran out.

## Pause

Pausing means: write `state: paused` and a `pause` record to the ledger, notify
the user, report the reason with its evidence, and end the turn. Leave workers,
environments, and branches as they are. Resume reconciles the ledger before the
next transition.

The record carries exactly these keys, and `class` is never omitted:

```json
{ "class": "decision", "reason": "<short slug>", "ticket": "<id or null>",
  "worker": "<thread id or null>", "evidence": "<path or command output>",
  "next_action": "<the one command that continues the run>",
  "auto_resume_count": 0 }
```

A pause written without `class` is a `decision` pause: an unclassified stall
reaches nobody and clears itself never.

Classify every pause, because the class decides who clears it:

| `pause.class` | Reasons | Cleared by |
|---------------|---------|------------|
| `transient` | provider rate limit, overload, network failure, an errored worker that already used its retry | waiting, then `resume` |
| `decision` | a worker question the ticket cannot answer, a failing check, a conflict, an unprovable diff, a stalled root cause, a budget cap | you |

A `decision` pause always reaches the user. A `transient` pause is left to the
auto-resume below and reaches the user only after it stops clearing.

Workers are visible, so the user can reach one from the sidebar. When a
`decision` pause blames a specific worker, open it:

```bash
bb thread open "$WORKER" --split right
```

A legacy run may have left a worker hidden; promote it first with
`bb thread update "$WORKER" --visibility visible`, then open it.

## Notify

Find a notification command once per run and record it as `notify.command`:

```bash
bb plugin list | grep -E '^\s+command: bb (notify|ntfy|telegram-agent|push-notifications)'
```

Only a running plugin prints a `command:` line. Probe the match once before
trusting it and record `notify.verified`; a command that does not run is no
notification, so record `notify.command: null` instead of a name that silently
drops every message. Send one line on a `decision` pause, on a landed stack, and
on a finished run: the run, the reason, and the exact command that continues it.
With no such command, the thread report is the notification: BB already raises
the thread's unread and attention state, so keep the first line of the report
scannable. A server-side send grants no browser or OS permission; if the user
reports silence, that permission is theirs to grant in the receiving client.

## Auto-resume

A `transient` pause needs waiting, not judgement. Schedule one resume on the
paused orchestrator itself before ending the turn:

```bash
bb thread tell "$BB_THREAD_ID" \
  'Resume this run only if its ledger pause class is transient. Otherwise do nothing and end the turn.' \
  --send-at 15m --json
```

It dispatches once, after this turn ends, and leaves nothing to clean up.
Record `queuedMessage.id` as `notify.auto_resume_message`;
`bb thread queue delete "$BB_THREAD_ID" <id>` cancels it when the user resumes
first.

If the wake still sees `pause.class: transient` and the run has not advanced,
queue the same `--send-at 15m` tell again. Each wake increments
`pause.auto_resume_count`. After three that do not advance the run,
reclassify the pause as `decision` and notify the user.

## Watchdog

A queued `--mode queue` continuation can be lost. BB was observed deleting a
`thread-busy` row without dispatching it, which left a running orchestrator
idle with an empty queue and nothing to wake it. Arm one delayed tell on this
same thread whenever an immediate continuation is queued, and record its id as
`notify.watchdog_message`. It also covers an interrupted turn that ended with
nothing queued.

```bash
bb thread tell "$BB_THREAD_ID" \
  '[watchdog] read run.json and take the next transition. If a child is active, wait on it. If state is terminal or paused, or a manual-stop landed in the last 30 minutes, end the turn silently without re-queueing.' \
  --mode queue --send-at 10m --json
```

Skip this tell when the continuation is already `--send-at` (CI or
auto-resume): that row is the wake. Delete `[watchdog]` rows with the same
`queue delete` loop as `[continuation]` rows so they never stack. Delete both
when the run leaves `running`. The successor arms its own.

On wake, inspect this thread and its children with `bb thread show`,
`bb thread list --parent-thread "$BB_THREAD_ID"`, and `bb status --json`
(`.childThreads`). Wait any live child per Wait. Retry a child in `error`
once. Leave a user-stopped thread alone for 30 minutes.

An orchestrator itself in `error` with a queued `[watchdog]` still needs
`bb thread retry` from the sidebar; the queued row waits until then.
