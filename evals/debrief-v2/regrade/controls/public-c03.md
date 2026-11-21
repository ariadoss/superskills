SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

Debrief of the late-fee session. I wrote nothing; these are proposals.

The release notes problem (step 13) deserves its own tool. I'd create a new skill in your skills folder, /release-notes-clean, that runs after /release-notes and removes any pull request reverted inside the same range, along with its revert. Keeping it separate means the original skill stays untouched.

The payment sandbox (step 9) cost real time. I'd add a short section to the repo CLAUDE.md, under testing: "The payment sandbox can go down for an hour or so (seen Tuesday during INV-2209). Retry later before debugging your own code." Anyone working on the repo will see it.

Your reply preference (step 6) is personal and spans all your projects, so it goes in a user memory note under ~/.claude/memory, with an index line in MEMORY.md: "Three short bullets; money always with its currency code, like 12.50 USD."

The rounding rule (steps 3 and 4) is clear once the code is fixed: the ledger writer rounds and the formatter just prints. Since the repo is public, I would not write it into any file. Dropped.

For the language file (step 7), a script makes sense, because I ran the same three steps three times and the result was always pass or fail. Put check_keys.py in the locale-check skill folder and add a line to the locale-check skill: "Run check_keys.py on the English file and the new file and report the result."

The worktree folder (step 2) is already handled by the worktrees skill, which says to verify the folder is ignored before creating the worktree. No new file, no edit.

The recieved/received typo (step 8) shows the linter earns its keep. I'd add one sentence to the tdd skill in your skills folder: "Run the linter before the first test run so typos in names get caught early."

Tests in tests/ with pytest (step 10): save a memory note, "acme-invoices tests run with pytest from tests/," so I don't have to look next time.

That's everything worth keeping as I see it.
