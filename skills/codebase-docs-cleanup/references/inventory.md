# Inventory and decision rules

Attach this file to every inventory worker. The orchestrator applies the same
rules when it merges the returned tables into a plan.

## What to inspect

Inspect the implementation before judging its documentation. Start from entry
points, public contracts, domain types, tests, and configuration, then follow
imports into representative implementation paths.

Inventory root and nested agent instructions, READMEs, docs folders, repository
skills and their references, architecture notes, glossaries, plans, and
explanatory comments. Include supported formats beyond Markdown where present.

## The table

Record one row per file or independently actionable section:

| Item | Audience / consumer | Classification | Evidence | Proposed action |
| --- | --- | --- | --- | --- |
| Path and heading | Agent, developer, customer, tooling | One of the classes below | Source, test, or config paths, inbound references, or unique knowledge | Keep, trim, merge, move, delete, or investigate |

## Classes

- **Mirror:** repeats behavior, file layout, commands, or types cheaply
  discoverable in code or configuration.
- **Drift:** conflicts with verified current behavior. Distinguish an obsolete
  description from a still-valid requirement the code violates.
- **Rationale:** decisions, rejected alternatives, constraints, trade-offs, and
  history needed to understand why.
- **Domain:** business meaning and distinctions identifiers or types cannot
  fully express.
- **Navigation:** concise routes to major subsystems or task-specific
  references.
- **Operational / human contract:** onboarding, recovery procedures, public API
  commitments, security guidance, accessibility or compliance requirements,
  licenses, release records, and other material with a consumer beyond agent
  exploration.
- **Unknown:** unsupported claims, uncertain ownership, unclear consumers, or
  meaning that cannot be recovered confidently.

One file may carry several classes. Read a file's full relevant content before
proposing to delete it. Search for inbound links, imports, documentation-build
inputs, generated-file sources, and tooling references before moving or removing
it; an unreferenced file is not automatically useless.

Tests and code are evidence of current behavior, not proof that the behavior
meets intended requirements. Flag a contradiction with a product specification
or security constraint for resolution instead of erasing the requirement.

## Decision rules

- Delete verified mirrors that serve no independent consumer; trim mixed
  documents section by section.
- Merge duplicated knowledge into one authoritative location and repair the
  incoming pointers.
- Preserve rationale in existing ADRs or a minimal decision record, and domain
  meaning in an existing glossary or the smallest appropriate home. Create
  either only when retained content warrants it.
- Correct verified stale descriptions. Keep uncertain facts unchanged and flag
  them; never invent decision history, alternatives, or definitions.
- Keep operational and human-facing material that remains useful, even when an
  agent could infer part of it. Improve or generate it from authoritative
  sources rather than applying the mirror rule indiscriminately.
- Retain an expensive-to-recover lookup only when its saved exploration cost
  justifies a cache; name its authoritative source and maintenance mechanism.
- When documentation compensates for confusing code, propose a bounded
  readability refactor before removing the explanation. When that refactor is
  too risky for this run, retain the explanation and record the follow-up.

## Coverage

Partition a large repository by subsystem and report the coverage each worker
actually reached. A partition that ran out of budget reports what it inspected;
it never implies a sample was exhaustive. The orchestrator either spawns another
worker for the remainder or records it as uninventoried scope in the report.
