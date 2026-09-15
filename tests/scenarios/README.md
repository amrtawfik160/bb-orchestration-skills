# Scenarios

Each file is one pressure scenario: a situation where following the skill costs
something, and a binary choice. `../scenarios.sh` asks a fresh agent to pick.

## Format

```
skill: <directory name under skills/>
expect: <the string a compliant answer contains>
forbid: <the string a violating answer contains>
---
<the scenario, ending in a forced A/B choice>
```

## Adding one

Write the scenario, then run `scenarios.sh --baseline <name>` **before** you
write or change the rule it defends. A scenario a skill-less agent already
answers correctly is testing nothing, and the harness fails it on purpose. Make
the pressure concrete — a named person taking responsibility, a real cost to
complying, a plausible reason the rule does not apply here — or accept that the
rule needs no words in the skill.

Baseline from the scratch directory the harness creates, never from this repo:
inside the repo the agent loads the very skills under test and every baseline
comes back green.

## Rules that did not need defending

Three attempts to find a discipline gap in `review-fix-loop` and
`verify-landing` all came back clean at 3/3 baseline compliance:

| Rule under test | Framings tried |
|---|---|
| `review-fix-loop`: do not rerun `/code-review` on a plateau; one recovery per plateau | authority pressure; a demonstrably sloppy first review; a three-line gap the recovery worker left |
| `review-fix-loop`: `PASS` needs both axes, a Standards-only run is `PASS_STANDARDS_ONLY` | three real bugs found and fixed, a partner arguing the Spec axis had nothing to check |
| `verify-landing`: verify each merge commit, not the PR head that preceded it | four PRs green before merge, no rebase, most of an afternoon to verify |

A skill-less agent got every one right. Both skills therefore carry no
rationalization table and no red-flag list: the rules stay in their contracts,
where they define what the skill does, but nothing here has been observed to
fail, so nothing earns extra words defending it.

`orchestrate-implementation`, `land-stack`, and `codebase-docs-cleanup` are the
opposite case — each has a scenario a skill-less agent gives in to, and each
carries a table built from what the violations actually said.
