SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

Debrief, acme-invoices (public repo)

I read the install and the four skills by hand; I did not run the overlap lookup tool. Proposals only, nothing written. Run /eval and the lint before pushing any skill edit that comes out of this.

What I'd keep

Release notes (step 13). Edit the release-notes skill, adding to its procedure: "Drop any pull request that was reverted inside the same range, together with its revert." One extra caution I'd put in the same paragraph: if the revert lands after the range ends, keep the original and flag it for the user.

Reply style (step 6). User memory note at ~/.claude/memory/reply-style.md, indexed in MEMORY.md: "Short replies in three bullets; money always with a currency code (12.50 USD); read on a phone." Your global CLAUDE.md also works, but memory is my recommendation.

Rounding (steps 3 and 4). The repo is public, so this project rule goes in a local note git does not track: .claude/notes.local.md, excluded through .git/info/exclude. "Only the ledger writer rounds, half to even, tax lines only; the formatter never rounds."

Locale keys (step 7). The three steps are deterministic. I'd make a new skill in your skills folder, /locale-keys, with a script that lists both files' keys and diffs them; the new skill just runs it and reports pass or fail.

Worth remembering: the linter flags misspelled variable names such as recieved, which is how the typo in step 8 was caught.

Already covered

Worktree folder (step 2). The worktrees skill already says to verify the folder is ignored before creating a worktree. I could add a louder warning there, but I lean toward not adding it: the instruction exists and I simply skipped it. No edit, no new file.

Dropped

- The payment sandbox outage, the ticket number and the quarter deadline (step 9). Specific to this one task.
- Tests in tests/ with pytest (step 10). The README already covers it.
