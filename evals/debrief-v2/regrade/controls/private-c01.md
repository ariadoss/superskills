SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

Debrief: late-fee branch

I read the session and the install: the repo CLAUDE.md, the four user skills, your global CLAUDE.md and the memory index. I did not run the overlap lookup tool; I read the skill descriptions by hand. These are proposals only. I wrote nothing.

Keep

1. Reverted pull requests in release notes (step 13). Edit the release-notes skill and add this sentence to its procedure: "Before writing the notes, drop any pull request that was reverted inside the same range, and drop its revert with it." You said every time, in every repo, so the skill is the right home rather than a project file.

2. Rounding (steps 3 and 4). One line in the repo CLAUDE.md: "Only the ledger writer rounds, half to even, on tax lines only. The formatter never rounds; it prints cents as given." This is a rule of this project's money code, and the repo is private, so it belongs with the other project rules.

3. Reply style (step 6). A user memory note at ~/.claude/memory/reply-style.md, with one index line in MEMORY.md: "Short replies in three bullets; always write money with its currency code, like 12.50 USD; read on a phone." Your global CLAUDE.md would also work, since it already has a line about plain replies, but memory is where I'd put it.

4. Locale completeness check (step 7). You ran the same three steps three times and got pass or fail each time. Write a small script, check_locale_keys.py, in the locale-check skill folder: it lists the keys in the English file, lists the keys in the new file, diffs them, and exits nonzero on any difference. Then add one line to the locale-check skill: "Run check_locale_keys.py <english file> <new file> and report pass or fail." The manual steps can stay as the explanation.

Already covered

5. Worktree folder nearly committed (step 2). The worktrees skill already says to verify that the directory is ignored before creating a worktree. The step was skipped, not missing. No new file and no edit. I could add a bolder reminder to the skill, but I would not: the instruction is already there and a second copy is noise.

Dropped

6. The payment sandbox errors, the ticket number and the quarter deadline (step 9). One-off facts about this task.
7. The recieved to received typo (step 8). Fixed in one edit; not a lesson.
8. Tests live in tests/ and run with pytest (step 10). The README already says it, and so does the repo CLAUDE.md.

Before pushing any skill edit from this list, run /eval and the lint.
