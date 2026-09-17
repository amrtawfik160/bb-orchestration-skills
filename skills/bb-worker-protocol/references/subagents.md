# In-thread sub-agent execution (explicit alternative only)

Use this protocol only when the user explicitly requests single-thread
execution. The default is one visible BB thread per phase with one chained
worktree per ticket, per `bb-workers.md`. This alternative keeps one
persistent BB thread and one existing checkout. Each ticket still owns
its own branch, pinned base, review evidence, and PR. Sub-agents are phase
workers inside that conversation; they are not new BB threads or environments.
User constraints and an existing run's recorded mode take precedence.

## Select and record the backend

Read `bb status --json` and the relevant live `bb` help through `bb-cli`.
Resolve the project and existing environment explicitly. Inspect the actual
callable agent tools supplied by the current provider. BB 0.43.1 has no
`bb subagent` command; do not invent one or treat `bb thread spawn` as native
sub-agent creation. Re-check the versioned claim on BB upgrade. The CLI owns BB context, durable queues, and thread state.
The provider's tools own native spawn, message, wait, interrupt, and results.

Record `execution.mode` as `bb-threads`, `subagents`, or `direct`, plus
`execution.owner_thread`, `execution.environment`, `execution.worktree`, and
`execution.shared_checkout`. New runs default to `bb-threads` with one chained
worktree per ticket and one visible BB thread per phase. Select `subagents`
only on explicit user request when native tools are callable. Do not select a
model, raise a permission level, or create another checkout merely to obtain
those tools.

If native tools are absent, use `direct`: continue authorized serial work in
the parent. Record independent review as unavailable; never call self-review
a fresh two-axis PASS. Leave that gate pending and advance independent work
that does not require it. `bb-threads` is the default backend in
`bb-workers.md`; this file's shared-checkout rules apply only to the
explicitly requested single-thread alternative.
An old ledger without `execution` predates the mode record: reconcile it as a
`bb-threads` run unless the user explicitly constrains otherwise; never
reinterpret its stored thread IDs as agent IDs.

## Shared checkout ownership

- The parent owns the graph, branch changes, ledger, integration, PRs, and
  final validation. Run tickets serially; grant at most one writer a bounded
  phase and named paths. The parent does not edit alongside that writer.
- Before a writing phase, record HEAD, index, and existing tracked/untracked
  changes. Preserve unrelated work; never stash, reset, clean, or stage it as
  part of another ticket. Verify the worker's actual checkout/path before edits.
- Before review, require a committed clean ticket diff and pin base and HEAD.
  Freeze the checkout for the whole read-only batch: no edits, branch switches,
  installs, builds that rewrite tracked files, or writer activity by any agent.
  Record tree/index/untracked state before and after, not only HEAD.
- Standards and Spec may run concurrently as two independent read-only agents.
  Do not run a nested coordinator or allow descendants. Wait for both before
  integrating or fixing. Other independent read-only audits may run together
  only when their evidence cannot change beneath them.
- An interrupt request does not prove a tool or process stopped. Confirm the
  worker and its in-flight commands are quiescent, inspect Git, and reconcile
  partial output before releasing its lease or starting another writer.

The parent may run validation during read-only review only when the commands
cannot mutate the reviewed inputs; record generated/untracked outputs and
keep them outside the frozen source state. Otherwise run validation first.

## One phase, one fresh context

Use the provider's actual native tools, such as this session's
`collaboration.spawn_agent`, `send_message`, `wait_agent`, and `list_agents`,
when present. Other providers may expose different names; inspect their tool
schemas rather than copying these names into a shell. Agent handles belong to
that provider session. BB `thread show`, `thread wait`, `thread output`, and
`thread archive` do not operate on those handles.

Give each worker the phase, exact repository path, pinned base/head, ticket
and standards source paths, allowed writes (or read-only), validation ownership,
and the result contract in `worker-footer.md`. Pass files using the native
tool's supported context mechanism; BB's `--file` flags are not native tool
arguments. A slash command in a task string is not proof that its skill ran:
provide accessible skill paths/content and verify it loaded the relevant rules.
Inherit the parent's model and permission settings unless the user or applicable
instructions specify otherwise.

Use fresh agents for implementation/diagnosis, finding verification, fixes,
and closure; do not reuse a reviewer's implementation context. The parent may
perform authorized implementation and fixes directly. Review independence
still requires separate fresh Standards and Spec contexts. Disable inherited
conversation history for these agents (for example, `fork_turns: "none"` when
that option exists), and supply a self-contained brief with the pinned inputs.
If the provider cannot isolate history, record independent review as unavailable
rather than claiming freshness from a new handle alone. Their reports are
evidence to verify, not authority to modify scope or declare completion.

Keep the established review contract: one initial two-axis review; verify
findings against code; reproduce behavioral defects; fix confirmed root causes;
then check those roots and fix-induced regressions. Preserve root IDs and the
convergence budget. Do not restart broad reviews just to seek a zero result.
Never run fixes against a moving base or combine unrelated ticket changes.

## Results and durable state

Store the worker's final report under the owner thread's storage before
recording acceptance. A completion notification alone is not a verified result.
Check the result footer, actual diff, ancestry, clean state, acceptance criteria,
and required local gates. A read-only worker must preserve its pinned snapshot.
Validation belongs to the exact source state tested; edits during a suite
invalidate attribution for affected inputs. Record unavailable hosted CI
separately and honor the repository's authorized local-gate policy.

Each worker record adds `backend`, `agent_id`, `agent_session`, `phase`,
`lease` (`read` or `write`), `status`, `base`, `head`, `verified`, and durable
`output`. Keep old `thread` and `last_seq` fields as historical BB-thread evidence.
Do not fabricate a BB thread ID for a native worker. Record the actual provider
session identifier when exposed; otherwise use a parent-generated execution
epoch, and require a live-tool lookup before reusing any handle.

On resume, first reconcile the owner thread/environment, Git refs and dirty
state, ticket PR base/head, accepted evidence, and queued continuation. Then
inspect workers through their recorded backend. A native handle absent from
the live provider session is stale, not running forever or successfully done.
Keep its history, reconcile any commits/partial edits, and restart only the
unfinished phase from verified state in a fresh agent. Do not revive archived
predecessor threads or repeat already accepted tickets.

## Ticket branches and PRs

Stop all workers before switching branches. Require a clean checkout, preserve
each accepted head under its ticket branch, then switch this same checkout to
the next ticket's branch at its approved base. Preserve dependency order and
one-ticket diffs. Fetch current main and integrate without discarding newer
fixes; resolve routine conflicts within scope, then review/test the integrated
result. A commit on the wrong branch is not ticket acceptance.

The parent pushes and opens each ticket's PR, using `show-me` for its body.
Check GitHub's actual head/base against that ticket's ledger. The shared BB
environment's PR association cannot identify all historical ticket branches.
Keep local, fixture, development, production, installed-runtime, channel, and
provider evidence distinct. A clean review does not authorize an otherwise
restricted deployment or close an unmerged ticket.

## Same-thread continuation

Persist state after every meaningful transition. If authorized work remains
when the parent must end, inspect `bb thread queue list <owner-thread> --json`
and queue one continuation on that same thread using current CLI syntax.
Deduplicate existing continuation rows. While workers run, use the provider's
wait/result tools inside the turn, with concise progress updates; do not spin
new turns or poll unchanged state rapidly. For an external scheduled wait,
record its reason and next wake time rather than enqueueing an immediate loop.

Context pressure is a reason to checkpoint and compact/continue this thread,
not to create a successor. Set `relay.successor` to null for this mode and do
not run the legacy relay procedure. Arm the `[watchdog]` tell on this owner
thread only. It verifies project, state, archive status, worker activity, and
the existing queue before taking a transition. Wait in-thread agents with the
provider's wait/list tools; wait BB children with `bb thread wait` and
`bb thread list --parent-thread`.

## Landing and cleanup

Honor the run's landing and deployment authorization. Land per-ticket PRs in
order after their reviewed heads, current target integration, required checks,
and any requested approvals are verified. Preserve each PR and closure record.
Use the existing stacked-PR rebase/retarget algorithm serially in the shared
checkout; do not delete a branch still needed as another ticket's base.

In shared-checkout mode, skip per-ticket environment archival/retirement and
worktree deletion. Never archive the owner thread or delete the active checkout
as part of landing. Avoid `gh pr merge --delete-branch` when it would switch or
delete the shared checkout's branch. Leave optional branch/environment cleanup
for an explicitly authorized final action after all dependent work and stored
refs are accounted for. Completing one ticket never destroys the run's workspace.
