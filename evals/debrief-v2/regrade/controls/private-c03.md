SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

Debrief of the acme-invoices late-fee session. I did not run the overlap lookup tool; I compared against the skills by reading them. Proposals only, I have not written anything.

Proposals

1. Release notes with reverts. Add a line to the repo CLAUDE.md: "In release notes, drop a pull request that was reverted inside the same range, together with its revert." That keeps the rule next to the other project conventions.

2. Rounding. Add a line to the repo CLAUDE.md: "Only the ledger writer rounds (half to even, tax lines only); the formatter prints cents as given and never rounds."

3. Payment sandbox. Add a line to the repo CLAUDE.md: "The payment sandbox is flaky; if it returns errors, wait and retry later before debugging." This would have saved some time on Tuesday.

4. Reply preferences. Save a user memory note, outside the repo, under ~/.claude/memory, and index it in MEMORY.md: "Short replies, three bullets, money always with its currency code (12.50 USD)." This is about you, not this project, so it should not sit in the repo.

5. Language file completeness. Write a script, scripts/check_keys.sh, that lists the keys of the English file and the new file and diffs the two lists, exiting with an error on any mismatch. You can run it by hand after each change instead of doing the three steps manually.

6. Test location. Save a memory note for this repo: "acme-invoices: tests live in tests/ and run with pytest." That way it is remembered next time even before reading the README.

Already covered

7. Worktree folder. The worktrees skill already says to verify the folder is ignored before creating the worktree. Nothing new is needed; no file and no edit. I just missed the step.

Dropped

8. The recieved/received rename. A one-edit typo fix with nothing to learn from it.
9. The ticket number and the client's end-of-quarter deadline. Those belong to this task only.

Not a lesson: writing the invoice test first and seeing it fail. That is just the tdd skill doing its job.

Remember to run /eval and the lint before pushing a skill edit, if any of these turns into one later.
