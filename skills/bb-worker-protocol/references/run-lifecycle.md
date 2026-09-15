# Run lifecycle

How a run survives longer than one turn: queueing its own continuation,
handing off before context runs out, pausing, telling the user, and the
watchdog that re-arms a run nobody woke. `bb-workers.md` owns everything
inside a single worker; this file owns everything between turns.

## Continue the run

A run outlives one turn. Ending a turn is not pausing: a turn that stops with
work left and nothing queued leaves the run waiting for a human who does not
know it is waiting.

A turn may end only in a terminal state — `finished`, `landed`, `audited`, or
`paused` with `class: decision` — or with exactly one continuation queued.
Queue it as the turn ends, not as it starts: every queued row renders in the
IDE Queue panel, so a row queued at turn start sits as a `Queue 1` badge for
the whole turn. An interrupted or errored turn with nothing queued is covered
by the watchdog below, which re-arms a running ledger found idle or errored
with an empty queue.

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
  | jq -r '.[] | select(.content[].text | test("^\\[continuation\\]|^Continue this run from its ledger")) | .id' \
  | while read -r row; do bb thread queue delete "$BB_THREAD_ID" "$row"; done
```

Record the queued row's id as `notify.continuation_message` where the ledger
tracks one, and delete the row when the turn reaches a terminal state. On
wake, read the ledger first: a terminal or paused state ends the turn
silently after clearing stale continuation rows, never with a fresh queue.

A brief `[continuation]` row between turns is normal: it auto-dispatches at
turn end and is safe to ignore. Deleting it only delays the run until the
watchdog re-arms it, within ten minutes. Say so in one line when the user
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

The successor saves the ledger first: the watchdog scans per-thread storage,
so a successor with no ledger of its own is invisible to it.
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

When a run needs a repeating resume that outlives a stopped thread, create one
auto-resume automation per run instead, and
delete that automation when the run leaves `paused`:

```bash
bb automation create --project "$BB_PROJECT_ID" --name "resume <run>" \
  --cron '*/15 * * * *' --timezone "$TZ" \
  --target-thread "$BB_THREAD_ID" --provider <id> --model <model> \
  --prompt 'Resume this run only if its ledger pause class is transient. Otherwise do nothing and end the turn.'

bb automation delete <automationId> --project "$BB_PROJECT_ID" --yes
```

Each auto-resume increments `pause.auto_resume_count`. After three that do not
advance the run, reclassify the pause as `decision` and notify the user.

## Watchdog

A queued continuation can be lost. BB was observed deleting a `thread-busy`
row without dispatching it, three times in one day, which left a running
orchestrator idle with an empty queue and nothing to wake it. It also covers
an interrupted or errored turn that ended with nothing queued, which is why
continuations queue at turn end instead of turn start. Guard every run with
one script automation that re-arms a run found idle with an empty queue while
its ledger still says `running`, and record its ID as
`notify.watchdog_automation`. It leaves alone a thread the user stopped in
the last 30 minutes: a user stop is a decision, and only the user resumes
past it.

```bash
cat > "$BB_THREAD_STORAGE/watchdog.sh" <<'EOF'
#!/usr/bin/env bash
# Re-arm any running run of this project that is idle with an empty queue.
for ledger in "$STORAGE"/thr_*/orchestrate-implementation/run.json "$STORAGE"/thr_*/codebase-docs-cleanup/run.json "$STORAGE"/thr_*/review-fix-loop/*.json; do
  [[ -f "$ledger" ]] || continue
  thread=$(basename "$(dirname "$(dirname "$ledger")")")
  IFS=$'\t' read -r state successor < <(jq -r '[(.state // ""), (.relay.successor // "")] | @tsv' "$ledger")
  [[ "$state" == running ]] || continue
  [[ -z "$successor" || "$successor" == "$thread" ]] || continue
  show=$(bb thread show "$thread" --json) || continue
  [[ "$(jq -r .thread.projectId <<<"$show")" == "$BB_PROJECT_ID" ]] || continue
  status=$(jq -r .thread.status <<<"$show")
  [[ "$(bb thread queue list "$thread" --json | jq length)" == 0 ]] || continue
  stopped=$(bb thread log "$thread" --format json --all | jq --argjson since "$(( $(date +%s%3N) - 1800000 ))" '[.[] | select(.type=="system/thread/interrupted" and .data.reason=="manual-stop" and .createdAt > $since)] | length')
  [[ "$stopped" == 0 ]] || { echo "left $thread alone: user-stopped in the last 30 minutes"; continue; }
  if [[ "$status" == idle ]]; then
    bb thread tell "$thread" "Watchdog: this thread was idle with an empty queue while $ledger is running. Read that ledger and take the next transition per its skill; if it is terminal or paused, end the turn silently." --mode auto --json >/dev/null
    echo "re-armed $thread"
  elif [[ "$status" == error ]]; then
    # One retry per stale failure: skip when a turn failed in the last 30 minutes.
    recent=$(bb thread log "$thread" --format json --all | jq --argjson since "$(( $(date +%s%3N) - 1800000 ))" '[.[] | select(.type=="turn/completed" and .data.status=="failed" and .createdAt > $since)] | length')
    if [[ "$recent" == 0 ]]; then bb thread retry "$thread" --json >/dev/null && echo "retried $thread"; else echo "ATTENTION $thread failed $recent turn(s) in the last 30 minutes"; fi
  fi
done
EOF
bb automation create --project "$BB_PROJECT_ID" --name "watchdog <run>" \
  --cron '*/10 * * * *' --timezone Etc/UTC \
  --script-file "$BB_THREAD_STORAGE/watchdog.sh" --interpreter bash \
  --timeout 300000 \
  --env-json "{\"STORAGE\":\"$(dirname "$BB_THREAD_STORAGE")\"}" --json
```

Pass `--timeout` explicitly. The default is 120000 ms and this script pages
`bb thread log --all` once per candidate ledger, so a project with several runs
overruns it and BB records a failed tick — a watchdog that stopped guarding
without saying so. Keep it under the cron interval so a slow tick finishes
before the next is due: 300000 ms against `*/10`. The plugin's 900000 ms
ceiling is longer than that interval, so it is the wrong value here.

Script and agent automations take disjoint flag sets; mixing them is rejected
with "Script automations do not accept agent execution flags." `bb automation`
comes from the `automations` plugin, not the core CLI — see this skill's
Dependencies table for what a run does when it is missing.

The script prints nothing when every run is healthy, so BB records a silent
tick. A relay needs no change: the script follows `relay.successor` from the
ledgers, and ledgers without a relay field pass the check, so one automation
covers every orchestration, landing, loop, and cleanup run of the project.
Delete it when no run of the project is `running`.
