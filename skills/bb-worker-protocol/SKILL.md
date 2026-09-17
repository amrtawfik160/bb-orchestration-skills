---
name: bb-worker-protocol
description: "Use when an orchestration skill needs the shared BB runtime contract: spawning and waiting on worker threads, verifying their claims, the run ledger schema, the stacked-PR procedure, or the WORKER_RESULT footer. Loaded by orchestrate-implementation, review-fix-loop, land-stack, verify-landing, and codebase-docs-cleanup rather than invoked on its own."
disable-model-invocation: true
---

# BB worker protocol

The runtime every orchestration skill in this bundle shares. It owns *how* a
run talks to BB; each skill owns *what* its run decides. Nothing here is a
workflow: this skill is never invoked on its own.

Split it this way because the alternative is five copies that drift. One
worker rule written five times is five rules the moment one is edited.

## References

| File | Owns |
|---|---|
| `references/bb-workers.md` | One worker: spawn, wait, interactions, result parsing, verification, budgets |
| `references/run-lifecycle.md` | Between turns: continuation, relay, pause, notify, auto-resume, `[watchdog]` tell |
| `references/github.md` | `gh` / `gh-axi` access. Read by skills that never spawn a worker |
| `references/worker-footer.md` | The `WORKER_RESULT` footer every worker ends with. Attach it to every spawn |
| `references/validation.md` | Resolving and running the `validation` command |
| `references/run-ledger.md` | The `run.json` schema shared by orchestrate-implementation, land-stack, and verify-landing |
| `references/pr-stack.md` | Baselines, checks, ready state, merges, rebases, and review comments once a PR exists |
| `references/example-run.md` | One three-ticket run end to end, with the real values at each gate |
| `references/subagents.md` | The in-thread alternative. Explicit user request only; never the default |

## Dependencies

`bb-workers.md` assumes these are present. Resolve them in Prepare, not at the
gate that needs them:

| Dependency | Probe | Absent |
|---|---|---|
| `bb` CLI | `bb --version` | Nothing in this bundle runs. Stop |
| a notification command | `bb plugin list \| grep -E '^\s+command: bb (notify\|ntfy\|telegram-agent\|push-notifications)'` | Record `notify.command: null`. The thread report is the notification. Never record a plugin name that is installed but disabled |
| `gh` / `gh-axi` | `gh auth status` | No PR work. Pause before the first push, not after |

A disabled plugin prints no `command:` line, so the grep already excludes it.
Probe the match once and record `notify.verified` before trusting it.

## Red flags — stop and re-read the protocol

- "I'll just check the worker log to see how it's doing" — see Wait
- "The footer says it committed, that's good enough" — see Verify a mutating worker
- "Nothing left this turn, I'll end here" — see Continue the run; ending is not pausing
- "I'll archive the worker to clean up" — archiving destroys the managed worktree
- "The reviewer found nothing, so I'll rerun the review to be sure" — reviews are nondeterministic
- "I'm near the context limit, I'll fork myself" — a fork inherits the exhausted context
- "I'll cron a sidecar to watch the workers" — see Wait and Watchdog
