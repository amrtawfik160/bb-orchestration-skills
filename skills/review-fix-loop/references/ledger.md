# Review-fix-loop ledger

Path: `$BB_THREAD_STORAGE/review-fix-loop/<review-base-7-char-sha>.json`.
When `orchestrate-implementation` applies the loop, the same object lives under
`tickets.<id>.loop` in the run ledger instead.

Write the file after every transition: a spawn, an idle worker, a verified
result, a finding disposition, a pause. On resume, reconcile every recorded
SHA against Git and every worker status against `bb thread show` before the
next transition.

```json
{
  "schema": 1,
  "state": "running",
  "environment": "env_abc123",
  "worktree": "/path/to/worktree",
  "branch": "bb/ticket-42",
  "review_base": "0123456789abcdef0123456789abcdef01234567",
  "initial_head": "89abcdef0123456789abcdef0123456789abcdef",
  "spec": "/path/to/attached/ticket.md",
  "validation": "pnpm test && pnpm lint",
  "budget": { "workers": 8, "minutes": 240, "started_at": "2026-09-03T10:00:00Z" },
  "phases": {
    "review": { "provider": "claude-code", "model": null },
    "fix": { "provider": null, "model": null }
  },
  "workers": [
    {
      "phase": "review",
      "thread": "thr_abc123",
      "status": "idle",
      "last_seq": 412,
      "base": "89abcdef0123456789abcdef0123456789abcdef",
      "head": "89abcdef0123456789abcdef0123456789abcdef",
      "verified": true,
      "output": "review-fix-loop/0123456/review.md"
    }
  ],
  "findings": [
    {
      "id": "standards-1",
      "axis": "standards",
      "root_cause": "duplicated retry logic in two handlers",
      "verdict": "CONFIRMED",
      "state": "OPEN",
      "fix_base": null,
      "fix_head": null
    }
  ],
  "best_burden": 1,
  "recovery_used": false,
  "gate": { "verdict": null, "final_head": null, "open_confirmed_findings": null },
  "pause": null
}
```

Field notes:

- `state` is `running`, `paused`, or `finished`.
- `findings[].verdict` is `CONFIRMED` or `DISPUTED`; `state` is `OPEN`,
  `RESOLVED`, or `CONFIRMED_FIX_REGRESSION`. Reuse an ID for the same root cause.
- `best_burden` is the lowest count of distinct open root causes seen so far.
- `pause` is
  `{ "class", "reason", "worker", "evidence", "next_action", "auto_resume_count" }`
  when paused, where `class` is `transient` or `decision`.
- `workers[].output` is the saved final message, relative to
  `$BB_THREAD_STORAGE`.
- `workers[].last_seq` is the highest thread-log event sequence already read for
  that worker; the next wait window pages from it with `--after-seq`.

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
