# Cleanup ledger

Path: `$BB_THREAD_STORAGE/codebase-docs-cleanup/run.json`. Write it after every
transition: a frozen baseline, a spawn, an idle worker, a merged inventory, a
plan, a verified batch, a navigation check, a pause. `resume`, or an existing
ledger at start, reconciles every recorded SHA, worker, and path against Git
and `bb thread show` before the next transition.

```json
{
  "schema": 1,
  "state": "running",
  "mode": "apply",
  "project": "proj_abc123",
  "environment": "env_abc123",
  "worktree": "/path/to/worktree",
  "branch": "bb/docs-cleanup",
  "base_branch": "main",
  "cleanup_base": "0123456789abcdef0123456789abcdef01234567",
  "validation": "pnpm test && pnpm lint",
  "baseline": {
    "result": "FAIL",
    "known_failures": ["tests/legacy/import.test.ts"],
    "unavailable": ["playwright browsers"]
  },
  "untracked_out_of_scope": ["notes/scratch.md"],
  "excluded_scope": ["vendor/", "dist/"],
  "budget": { "workers": 12, "minutes": 240 },
  "notify": {
    "command": null,
    "auto_resume_message": null,
    "auto_resume_automation": null,
    "watchdog_automation": null,
    "continuation_message": null
  },
  "relay": { "predecessor": null, "successor": null },
  "partitions": [
    {
      "name": "src/payments",
      "worker": "thr_abc123",
      "status": "idle",
      "coverage": "complete",
      "verified": true
    }
  ],
  "inventory": [
    {
      "path": "docs/payments.md",
      "heading": "Settlement walkthrough",
      "audience": "agent",
      "class": "mirror",
      "evidence": "src/payments/settle.ts",
      "action": "delete",
      "preserve": null
    }
  ],
  "batches": [
    {
      "id": "B-1",
      "paths": ["docs/payments.md"],
      "benefit": "one authoritative settlement source",
      "preserve": [{ "knowledge": "why polling was rejected", "destination": "docs/decisions/settlement.md" }],
      "state": "done",
      "worker": "thr_def456",
      "base": "0123456789abcdef0123456789abcdef01234567",
      "head": "89abcdef0123456789abcdef0123456789abcdef",
      "validation": "PASS",
      "verified": true
    }
  ],
  "navigation_checks": [
    {
      "subsystem": "payments",
      "entry": "AGENTS.md",
      "worker": "thr_ghi789",
      "result": "reached",
      "guesses": 0
    }
  ],
  "pause": null
}
```

Field notes:

- `state` is `running`, `paused`, `audited`, or `finished`. `mode` is `audit` or
  `apply`; an `audit` run ends at `audited` with `batches` planned and unstarted.
- `baseline.result` is `PASS`, `FAIL`, or `NOT_RUN`, captured once at
  `cleanup_base`. A failure listed in `known_failures` is never evidence against
  a batch.
- `untracked_out_of_scope` records source-checkout files the managed worktree
  never received, so the report can say what this run could not see.
- `partitions[].coverage` is `complete` or a plain-language description of what
  the worker actually reached.
- `inventory[].class` is one of the classes in `inventory.md`, and `action` is
  `keep`, `trim`, `merge`, `move`, `delete`, or `investigate`. `preserve` names
  the knowledge and its destination, or is `null`.
- `batches[].state` is `planned`, `running`, `done`, `reverted`, or `deferred`.
- `navigation_checks[].result` is `reached`, `guessed`, or `lost`. Anything but
  `reached` fixes the pointer and records a new check.
- `pause` is
  `{ "class", "reason", "batch", "worker", "evidence", "next_action", "auto_resume_count" }`,
  where `class` is `transient` or `decision`.
- `notify.watchdog_automation` is the script automation that re-arms this
  thread when it is idle with an empty queue while `state` is `running`.
- `notify.continuation_message` is the queued `[continuation]` row that
  continues the run; it is deleted when the run reaches a terminal state.
- `relay.successor` is the orchestrator thread that took the run over on a
  context handoff; `relay.predecessor` is the thread it came from.
- The run also stores each worker's saved output, the merged inventory, and the
  plan under `$BB_THREAD_STORAGE/codebase-docs-cleanup/`.

## Execution records

The unit here is one visible BB thread per inventory partition, batch, and
navigation check, all sharing the cleanup worktree.
`../../bb-worker-protocol/references/run-ledger.md` owns what a worker record
holds and what the single-thread alternative changes.
