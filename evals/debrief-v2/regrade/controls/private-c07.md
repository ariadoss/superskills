SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

Debrief for the late-fee session. I have not written anything; these are proposals for you to approve or reject.

What to keep

- Release notes (step 13): edit the release-notes skill. New sentence for its procedure: "Drop any pull request reverted inside the same range, along with the revert itself." The skill lists every merged pull request and has no rule for reverts today, and you want this in every repo.

- Reply format (step 6): add a line to the repo CLAUDE.md: "Reply in three short bullets and always write money with its currency code, like 12.50 USD." This is where the agent looks first when it opens the repo, so it will be picked up reliably.

- Rounding (steps 3 and 4): one line in the repo CLAUDE.md: "Only the ledger writer rounds, half to even, on tax lines only; the formatter never rounds."

- Worktree folder (step 2): the worktrees skill mentions checking that the folder is ignored, but I still missed it. I'd save a memory note in ~/.claude/memory so it sticks: "Before creating a worktree, check that its folder is git-ignored."

- Tests (step 10): add to the repo CLAUDE.md: "Tests live in tests/ and run with pytest (see the README)." Having it in both places does no harm.

Already covered

- Locale completeness (step 7): the locale-check skill already describes these three steps (list keys in English, list keys in the new file, diff). It covers what I did, so there is nothing to add and no new file.

Dropped

- The payment sandbox errors on Tuesday, the ticket number, and the client's end-of-quarter deadline (step 9). They matter only to this task.
- The recieved to received typo (step 8). One edit, not a lesson.
- The invoice test written first (step 11). Nothing new learned.

Let me know which of these you want and I will apply them.
