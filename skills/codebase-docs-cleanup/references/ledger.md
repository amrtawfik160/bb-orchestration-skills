# Cleanup ledger

Path: `$BB_THREAD_STORAGE/codebase-docs-cleanup/run.json`. Write it after every
transition: a frozen baseline, a spawn, an idle worker, a merged inventory, a
plan, a verified batch, a navigation check, a pause. `resume`, or an existing
ledger at start, reconciles every recorded SHA, worker, and path against Git
and the recorded execution backend before the next transition. Use native
agent tools for native handles and `bb thread show` only for BB-thread workers.

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
    "command": "bb notify send",
    "auto_resume_message": null,
    "auto_resume_automation": null
  },
  "partitions": [
    {
      "name": "src/payments",
      "worker": "thr_abc123",
      "status": "idle",
      "last_seq": 412,
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
  the worker actually reached; `last_seq` is the highest thread-log event
  sequence already read for it.
- `inventory[].class` is one of the classes in `inventory.md`, and `action` is
  `keep`, `trim`, `merge`, `move`, `delete`, or `investigate`. `preserve` names
  the knowledge and its destination, or is `null`.
- `batches[].state` is `planned`, `running`, `done`, `reverted`, or `deferred`.
- `navigation_checks[].result` is `reached`, `guessed`, or `lost`. Anything but
  `reached` fixes the pointer and records a new check.
- `pause` is
  `{ "class", "reason", "batch", "worker", "evidence", "next_action", "auto_resume_count" }`,
  where `class` is `transient` or `decision`.
- The run also stores each worker's saved output, the merged inventory, and the
  plan under `$BB_THREAD_STORAGE/codebase-docs-cleanup/`.

## Native execution and legacy migration

For the default shared checkout, follow
`../../review-fix-loop/references/subagents.md`. Add `execution` with `mode`,
`owner_thread`, `environment`, `worktree`, and `shared_checkout`. The example
above illustrates historical BB-thread records; preserve them during migration.

Store workers in a `workers` registry keyed by a stable local record ID. Each
record contains `backend`, `agent_id`, `agent_session`, `phase`, `lease`,
`status`, `base`, `head`, `verified`, and a durable `output` path. New
`partitions[].worker`, `batches[].worker`, and `navigation_checks[].worker`
values reference this registry; they are not implicitly BB thread IDs. Keep
historical `thr_*` values and `last_seq` as BB-thread evidence. Never pass a
native handle to a BB thread command.

On resume, reconcile Git and saved reports, then inspect the recorded backend.
Missing native session handles are stale: preserve their evidence, reconcile
partial edits, and restart only unfinished phases in fresh isolated contexts.
Do not revive archived predecessors or repeat accepted batches. Shared mode
records out-of-scope dirty/untracked files in place and preserves them; it does
not create a managed checkout to exclude them.
