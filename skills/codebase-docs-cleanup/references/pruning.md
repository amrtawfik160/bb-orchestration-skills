# Pruning and readability rules

Attach this file to every cleanup batch worker. It covers what a batch may
change in prose and in code.

## Prose: five tests, sentence by sentence

1. **Single source:** is this meaning already authoritative in code, config, or
   another document? Keep one authoritative home instead of paraphrasing it in
   several places.
2. **No-op:** would removing the instruction change the agent's behavior? Remove
   generic explanations the model already knows; retain real constraints and
   project-specific gotchas.
3. **Relevance:** does the statement still apply to a real task? Remove obsolete
   layers rather than polishing them.
4. **Hierarchy:** keep universally needed actions inline; put branch-specific
   reference behind a pointer that says exactly when to read it.
5. **Completion:** replace vague instructions with observable done-conditions.
   Preserve functionality rather than optimizing for shortness.

Read the `writing-for-agents` skill when it is installed; these tests keep this
workflow usable without it.

## Always-loaded instructions

Keep `AGENTS.md` and `CLAUDE.md` focused on project-wide constraints and compact
conditional pointers. Preserve effective instruction scope and harness-specific
behavior when consolidating them: an instruction that only applied to one
directory must not silently become global, and one that only applied to one
harness must not silently apply to all. Do not restate the directory tree or
copy scripts out of the package manifest.

## The navigation layer

A thin navigation layer names a task or subsystem and its stable entry point. It
helps an agent reach code; it never becomes a replacement description of the
code. Every pointer states the condition that should make an agent read it.

Examples, with illustrative paths only:

- A doc enumerates package scripts: replace the duplicate list with a pointer to
  the manifest, preserving any non-obvious setup prerequisite.
- A service walkthrough repeats the implementation: remove that prose once the
  source is verified navigable, and retain the paragraph explaining why the
  previous approach was rejected.
- A glossary defines an order as a business commitment rather than a cart:
  retain that distinction even though an `Order` type exists.
- A deployment runbook includes a required recovery sequence: retain the
  operational knowledge rather than treating it as redundant implementation
  detail.
- A useful conditional pointer: `When changing payment settlement, read
  docs/decisions/settlement.md for the idempotency constraint; start
  implementation exploration at src/payments/settle.ts`.

Use actual inspected paths when applying these examples. Update incoming links
and documentation-build references in the same batch as the move or deletion.

## Code readability

Take this branch only where the inventory found a concrete readability problem.

- Follow the repository's formatter and naming conventions, and keep formatting
  scoped to the lines the batch touches.
- Improve misleading names, and place related behavior where the existing
  project structure makes it discoverable.
- Split an oversized module along real responsibilities so an agent can inspect
  a coherent piece without loading unrelated detail.
- Keep public contracts inspectable apart from implementation detail. Use the
  project's existing conventions and create an interface only where a real
  boundary benefits, never one per class.
- Replace a comment that narrates an obvious statement with clearer code.
  Preserve comments explaining a non-obvious constraint, an invariant, or why an
  approach exists.
- Preserve public APIs, serialized shapes, routes, persisted schemas,
  configuration semantics, import behavior, initialization order, and every
  other observable behavior. Add focused characterization tests before changing
  poorly covered behavior, and defer the refactor when equivalence cannot be
  checked credibly.
- Avoid unrelated dependency updates, architecture migrations, and
  whole-repository reformatting.
