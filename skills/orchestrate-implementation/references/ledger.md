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
    "command": "bb notify send",
    "verified": true,
    "auto_resume_message": "qmsg_abc123",
    "auto_resume_automation": null,
    "continuation_message": "qmsg_def456"
  },
  "landing": {
    "state": "pending",
    "method": "merge",
    "require_approvals": false,
    "keep_environments": false
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
        { "phase": "implement", "thread": "thr_abc123", "status": "idle", "last_seq": 412, "head": "89abcdef0123456789abcdef0123456789abcdef", "verified": true }
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
  unverified or missing command is `null`, never a plausible name.
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
- `workers[].last_seq` is the highest thread-log event sequence already read for
  that worker; the next wait window pages from it with `--after-seq`.
- `notify.auto_resume_message` is the scheduled resume queued on this thread;
  `notify.auto_resume_automation` is set only when a run uses the repeating
  automation instead. At most one of the two is non-null.
- `pause` is
  `{ "class", "reason", "ticket", "worker", "evidence", "next_action", "auto_resume_count" }`,
  where `class` is `transient` or `decision`. A `decision` pause that promoted
  its worker to visible also carries `"promoted_worker": true`.
- The run also stores every worker's saved output and both review reports
  under `$BB_THREAD_STORAGE/orchestrate-implementation/<ticket>/`.

## In-thread execution records

Follow `../review-fix-loop/references/subagents.md` from the skill directory
(`references/subagents.md` for review-fix-loop). Add `execution.mode`,
`execution.owner_thread`, `execution.environment`, `execution.worktree`, and
`execution.shared_checkout`. Native workers record `backend: subagents`,
`agent_id`, `agent_session`, `lease`, phase/status, pinned base/head, verified
result, and a durable output path. These are distinct from legacy `thread`
and `last_seq` fields; keep those unchanged as historical evidence.

Missing native handles after compaction/provider restart become stale pending
Git/result reconciliation. Restart only unfinished phases. A legacy ledger
without an execution mode is not silently migrated: reconcile the user's
constraint, preserve its old worker records, then record the chosen mode.
A shared checkout persists across tickets and landing. Native execution never
sets a relay successor or retires the owner's environment.
