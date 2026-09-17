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
  "attempts": [
    {
      "fix_head": "89abcdef0123456789abcdef0123456789abcdef",
      "validation": "pass",
      "failing": []
    }
  ],
  "quarantine": [
    {
      "check": "Runtime adapter contract",
      "pattern": "alternating",
      "evidence": "red c1, green c2, red c3",
      "ticket": "https://github.com/org/repo/issues/99"
    }
  ],
  "best_burden": 1,
  "recovery_used": false,
  "gate": { "verdict": null, "final_head": null, "open_confirmed_findings": null },
  "notify": {
    "auto_resume_message": null,
    "watchdog_message": null,
    "continuation_message": null
  },
  "pause": null
}
```

Field notes:

- `state` is `running`, `paused`, or `finished`.
- `findings[].verdict` is `CONFIRMED` or `DISPUTED`; `state` is `OPEN`,
  `RESOLVED`, or `CONFIRMED_FIX_REGRESSION`. Reuse an ID for the same root cause.
- `best_burden` is the lowest count of distinct open root causes seen so far.
- `attempts[]` holds one entry per fix, written by the orchestrator after
  running `validation` itself: the fix head, the result, and the failing
  checks. Attempts are evidence for quarantine and diagnosis, never a cap.
- `quarantine[]` holds one entry per flaked-out check: name, flake pattern,
  evidence, and repair ticket. A quarantined check gates nothing until a
  human acks or its ticket lands.
- `pause` is
  `{ "class", "reason", "worker", "evidence", "next_action", "auto_resume_count" }`
  when paused, where `class` is `transient` or `decision`.
- `notify.watchdog_message` is the delayed `[watchdog]` tell for a standalone
  loop; nested loops inside `orchestrate-implementation` use the run ledger's
  notify object instead.
- `workers[].output` is the saved final message, relative to
  `$BB_THREAD_STORAGE`.

## Execution records

The unit here is one visible BB thread per phase in one ticket environment.
`../../bb-worker-protocol/references/run-ledger.md` owns what a worker record
holds and what the single-thread alternative changes.
