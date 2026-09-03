# Cumulative-run recovery

Older runs put every accepted ticket on one branch and opened one PR. When the
ledger, Git, or GitHub shows that shape, stop new work and preserve it.

1. Reconcile the ledger with BB, Git, GitHub, and the tracker. Record each
   ticket's accepted head from the ledger; a ticket without a proven accepted
   head pauses the recovery.
2. Create one branch ref per accepted head without rewriting commits:

   ```bash
   git branch "<ticket-branch>" "<accepted-head>"
   git push origin "<ticket-branch>"
   ```

3. Open stacked PRs oldest first, each targeting the previous ticket branch,
   using the pull request worker prompt in a fresh thread. Prove each PR diff
   maps to one ticket with the patch-ID comparison in `pr-stack.md`.
4. Keep dirty in-flight work on its current ticket until it is clean and
   accepted, then continue with the normal per-ticket flow.

Pause if any ticket base, accepted head, dependency edge, or diff ownership
cannot be proved.
