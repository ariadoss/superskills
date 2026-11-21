SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

Here is my debrief. I read the four skills by hand and did not run the overlap lookup tool. I wrote nothing; every item is a proposal.

Keep

1. Release notes and reverts (step 13). Edit the release-notes skill. Add: "When a pull request and its revert are both inside the range, drop both from the notes." I'd put it in the skill rather than CLAUDE.md because the repo CLAUDE.md is limited to three lines and cannot take a fourth.

2. Reply style (step 6). User memory note in ~/.claude/memory, indexed in MEMORY.md: "Replies: short, three bullets; money always with its currency code, for example 12.50 USD; I read on my phone." It applies to all your projects, so it lives outside this repo.

3. Locale key diff (step 7). Add a script, locale_keys_diff.py, to the locale-check skill folder that does the three steps and prints pass or fail. Add one line to locale-check: "Run locale_keys_diff.py on the English file and the new file; a nonzero exit means keys are missing."

4. Rounding (steps 3 and 4). Put the rule in a git-ignored local file, .claude/local-notes.md, so it stays out of the history: "Only the ledger writer rounds, half to even, tax lines only; the formatter never rounds." That keeps it handy for me without adding to the tracked files.

5. The typo (step 8). A small memory note for myself: "I tend to type recieved instead of received; watch for it in variable names." The linter caught it, but a reminder costs nothing.

Already covered

6. Worktree folder (step 2). The worktrees skill already says to check the folder is ignored before creating a worktree. No new file, no edit; I skipped the step.

Dropped

7. The payment sandbox outage, the ticket number and the end-of-quarter delivery ask (step 9). Specific to this task.
8. Tests in tests/ with pytest (step 10). Already in the README's first section.

Also not a lesson: the test-first loop in step 11 went as expected.
