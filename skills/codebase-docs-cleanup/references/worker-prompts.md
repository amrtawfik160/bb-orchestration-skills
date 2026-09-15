# Worker prompts

One job per worker. Spawn and attachment rules live in `bb-workers.md`.

Inventory:
```text
Inventory <partition> for a code-first documentation cleanup.
Read the implementation before judging its documentation: start at entry points, public contracts, domain types, tests, and configuration, then follow imports into representative paths.
Classify every candidate file and independently actionable section with the attached rules, citing source, test, or config paths and inbound references as evidence. Read a file's full relevant content before proposing to delete it, and search for inbound links, imports, doc-build inputs, and tooling references first.
Keep the worktree unchanged. Return the table and the coverage you actually reached.
```

Cleanup batch:
```text
Apply the attached batch only, following the attached pruning and readability rules.
Write the knowledge it names to the destination it names before removing the source, and update incoming links and doc-build references in the same batch.
Preserve public APIs, serialized shapes, routes, persisted schemas, configuration semantics, and initialization order. Add focused characterization tests before changing poorly covered behavior; defer instead of asserting equivalence you cannot check.
Validate, commit, and leave the tree clean.
```

Cold-start navigation:
```text
You have not seen this repository before. Start only from <entry document> and read only what it and its pointers lead you to.
For <subsystem>, locate the implementation and its tests. Report the exact path sequence you followed and every point where you had to guess or search outside those pointers.
Keep the worktree unchanged.
```
