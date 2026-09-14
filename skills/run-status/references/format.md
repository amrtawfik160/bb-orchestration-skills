# Run-status format

Print every section in order. Values come from the ledger, `bb thread show`,
and read-only `gh pr view` and `gh pr checks`. `--` marks a field the ledger
lacks; never invent one.

## Run

One line: skill, run state, target, ticket tally, and the pause or gate line.

```text
RUN orchestrate-implementation running target=main tickets=1/3 pause=--
LANDABLE: no, #13 checks pending
```

Use the skill's own terminal line when the run reached one: `LANDABLE`,
`LOOP_GATE.verdict`, or `VERIFY_GATE.verdict`.

## Tickets

One row per ticket in `order`: state, PR and checks, environment, current
worker phase and thread.

```text
T-1 accepted pr#12:pass env:active implement thr_abc123
T-2 active pr#13:pending env:active review thr_def456
```

## Blockers

The pause record, quarantined checks with tickets, red-main responses, and
any missing gate verdict, one line each. All clear reads `BLOCKERS: none`.

## Children

One row per live child thread: ID, status, visibility, and title. End with
the ledger path for the full record.
