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
  "budget": { "workers": 12, "minutes": 360 },
  "notify": { "command": "bb notify send", "auto_resume_automation": "aut_abc123" },
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
        { "phase": "implement", "thread": "thr_abc123", "status": "idle", "head": "89abcdef0123456789abcdef0123456789abcdef", "verified": true }
      ],
      "loop": { "schema": 1, "state": "finished" },
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
- `criteria[]` records each acceptance criterion with the evidence that
  satisfied it, filled before the PR opens.
- `pr.checks` is `none`, `pending`, `pass`, or `fail`.
- `landing.state` is `pending`, `running`, `paused`, or `landed`;
  `landing.method` is `merge`, `squash`, or `rebase`.
- `tickets.<id>.landing.environment_state` is `active`, `archived`, or `kept`.
- `pause` is
  `{ "class", "reason", "ticket", "worker", "evidence", "next_action", "auto_resume_count" }`,
  where `class` is `transient` or `decision`.
- The run also stores every worker's saved output and both review reports
  under `$BB_THREAD_STORAGE/orchestrate-implementation/<ticket>/`.
