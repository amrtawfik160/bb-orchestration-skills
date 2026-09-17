# Run ledger

Path: `$BB_THREAD_STORAGE/orchestrate-implementation/run.json`. Write it after
every transition: a frozen graph, a spawn, an idle worker, a verified result, a
gate, a PR, a pause. `resume`, or an existing ledger at start, reconciles every
recorded SHA, thread, environment, PR, and tracker state against Git,
`bb thread show`, `bb environment show`, `gh pr view`, and the tracker before
the next transition.

```json
{
  "schema": 1,
  "state": "running",
  "project": "proj_abc123",
  "target_branch": "main",
  "remote": "origin",
  "tracker": "github",
  "spec": "/path/to/spec.md",
  "validation": "pnpm test && pnpm lint",
  "repeat_validation": ["1108"],
  "ci_baseline": {
    "measured_at": "0123456789abcdef0123456789abcdef01234567",
    "failing": ["Typecheck, lint, tests", "Runtime adapter contract"]
  },
  "budget": { "workers": 12, "minutes": 360, "run_workers": 240, "continuations": 200 },
  "progress": { "continuations": 3, "since_last_transition": 0 },
  "relay": { "predecessor": null, "successor": null },
  "notify": {
    "command": null,
    "verified": false,
    "auto_resume_message": "qmsg_abc123",
    "watchdog_message": "qmsg_w1",
    "continuation_message": "qmsg_def456"
  },
  "landing": {
    "state": "pending",
    "method": "merge",
    "require_approvals": false,
    "keep_environments": false
  },
  "verification": {
    "state": "pending",
    "smoke": "pnpm test:smoke"
  },
  "phases": {
    "implement": { "provider": "claude-code", "model": null },
    "diagnose": { "provider": null, "model": null },
    "review": { "provider": null, "model": null },
    "fix": { "provider": null, "model": null },
    "pr": { "provider": null, "model": null }
  },
  "graph": { "T-1": [], "T-2": ["T-1"], "T-3": ["T-2"] },
  "order": ["T-1", "T-2", "T-3"],
  "tickets": {
    "T-1": {
      "state": "in_review",
      "ticket_file": "/path/to/tickets/T-1.md",
      "route": "implement",
      "ticket_base": "0123456789abcdef0123456789abcdef01234567",
      "pr_base": "main",
      "environment": "env_abc123",
      "worktree": "/path/to/worktree",
      "ticket_branch": "bb/t-1",
      "accepted_head": "89abcdef0123456789abcdef0123456789abcdef",
      "started_at": "2026-09-03T10:00:00Z",
      "workers": [
        { "phase": "implement", "thread": "thr_abc123", "status": "idle", "head": "89abcdef0123456789abcdef0123456789abcdef", "verified": true }
      ],
      "loop": {
        "schema": 1,
        "state": "finished",
        "gate": { "verdict": "PASS", "final_head": "89abcdef0123456789abcdef0123456789abcdef", "open_confirmed_findings": 0 }
      },
      "criteria": [ { "text": "Users can export CSV", "evidence": "tests/export.test.ts" } ],
      "pr": {
        "url": "https://github.com/org/repo/pull/12",
        "number": 12,
        "base_ref": "main",
        "base_sha": "0123456789abcdef0123456789abcdef01234567",
        "head_sha": "89abcdef0123456789abcdef0123456789abcdef",
        "checks": "pass",
        "ready": true
      },
      "landing": {
        "merge_commit": null,
        "merged_at": null,
        "issue_state": "open",
        "environment_state": "active"
      },
      "verification": {
        "state": "pending",
        "checks": "none",
        "smoke": null,
        "response": null,
        "verified_at": null
      }
    }
  },
  "pause": null
}
```

Field notes:

- `state` is `running`, `paused`, `finished`, or `landed`.
- `tickets.<id>.state` is `ready`, `active`, `accepted`, `in_review`,
  `merged`, or `paused`.
- `route` is `implement` or `diagnose`.
- `loop` holds the full `review-fix-loop` ledger object for that ticket.
  `loop.gate` is the recorded `LOOP_GATE` block. The PR step reads
  `loop.gate.verdict`, so an absent verdict blocks the PR; `state: finished`
  alone is not a gate, because it does not say which axes ran.
- `ci_baseline.failing` lists the checks already failing on the target branch at
  `measured_at`. A PR failure named there is inherited and never blocks the run.
- `repeat_validation` lists the tickets whose diff touches time, clocks,
  concurrency, ordering, or randomness, so their suite is rerun rather than
  trusted once.
- `budget.run_workers` and `budget.continuations` cap the whole run, where
  `workers` and `minutes` cap one ticket.
- `progress.since_last_transition` counts continuations that recorded nothing.
  Two in a row pause with `class: decision` and `reason: no_progress`.
- `relay.successor` is the orchestrator thread that took the run over on a
  context handoff; `relay.predecessor` is the thread it came from.
- `notify.verified` records that `notify.command` was probed and ran. An
  unverified or missing command is `null`, never a plausible name — which is
  why the example above ships `null`. A probed command that ran replaces it
  with its exact string and `verified: true`. An *installed but disabled*
  plugin prints no `command:` line and is therefore not a match.
- `notify.continuation_message` is the queued row that continues the turn; it is
  deleted when the run reaches a terminal state.
- `criteria[]` records each acceptance criterion with the evidence that
  satisfied it, filled before the PR opens.
- `pr.checks` is `none`, `pending`, `pass`, `baseline_fail`, or `fail`.
  `baseline_fail` means every failure is in `ci_baseline`: the PR goes ready and
  the inherited failures are reported. Only `fail` blocks.
- `landing.state` is `pending`, `running`, `paused`, or `landed`;
  `landing.method` is `merge`, `squash`, or `rebase`.
- `tickets.<id>.landing.environment_state` is `active`, `archived`, or `kept`.
- `verification.state` is `pending`, `running`, `paused`, or `verified`.
  `tickets.<id>.verification.checks` reads like `pr.checks`, `smoke` is
  `pass`, `fail`, or `null`, and `response` records the red-main path taken
  with its revert PR or fix ticket.
- `notify.auto_resume_message` is the scheduled `--send-at` resume queued on
  this thread. A wake that is still transient queues another.
- `notify.watchdog_message` is the delayed `[watchdog]` tell that re-arms this
  thread when it is idle with an empty queue while `state` is `running`. It is
  deleted when the run leaves `running`. Older ledgers may still carry
  `watchdog_automation` or `auto_resume_automation`; ignore those keys.
- `pause` is
  `{ "class", "reason", "ticket", "worker", "evidence", "next_action", "auto_resume_count" }`,
  where `class` is `transient` or `decision`.
- The run also stores every worker's saved output and both review reports
  under `$BB_THREAD_STORAGE/orchestrate-implementation/<ticket>/`.

## Execution records

Default `execution.mode` is `bb-threads`: one visible BB thread per phase and
one chained worktree per ticket. Each worker records `thread`,
phase/status, pinned base/head, verified result, and a durable output path.
The single-thread alternative in
`subagents.md` applies only on explicit user
request; its native workers record `backend: subagents`, `agent_id`,
`agent_session`, and `lease` instead of BB thread fields. A ledger without an
execution mode predates the record and reconciles as `bb-threads` unless the
user constrains otherwise. Only `bb-threads` runs set a relay successor and
retire per-ticket environments at landing.
