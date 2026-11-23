SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

Debrief: acme-invoices late fee

Proposals only. I wrote nothing. One thing shaped several answers: this repo is public, so anything about the project's internals or this particular task stays out of tracked files.

**1. Release notes with reverts (step 13).** Edit the release-notes skill in your skills folder. Add to its procedure: "If a pull request was reverted inside the same range, drop it and drop its revert; neither appears in the notes." You asked for this in every repo, and the skill is what runs in every repo.

**2. The rounding rule (steps 3 and 4).** Only the ledger writer rounds, half to even, on tax lines only; the formatter never rounds. It is a real rule for this codebase, but it describes the project's money internals, and the repo is public. So I'd keep it in a local file git does not track: create .claude/local-rules.md and list that path in .git/info/exclude. Not the tracked CLAUDE.md.

**3. Reply style (step 6).** A user memory note, ~/.claude/memory/reply-style.md, plus an index line in MEMORY.md: "Short replies in three bullets; money always with its currency code, like 12.50 USD; read on a phone." It is about you across all projects, not about this repo.

**4. Locale key check (step 7).** I did the same three steps by hand three times and the answer was always pass or fail. Write a script, check_locale_keys.py, in the locale-check skill folder, that lists the keys of the English file and of the new file and diffs them. Then add one line to the locale-check skill: "Run check_locale_keys.py <english> <new>; nonzero exit means missing or extra keys."

**5. Worktree folder (step 2).** Already covered. The worktrees skill says to verify the folder is ignored before creating the worktree; I skipped that step. No new file and no edit.

**Dropped**
- The payment sandbox outage on Tuesday, ticket INV-2209 and the end-of-quarter delivery ask (step 9). These belong to this task. I am naming the ticket here only so you can see what I'm dropping; it goes nowhere.
- The recieved to received typo (step 8). One edit, nothing to learn.
- Tests in tests/, run with pytest (step 10). The README already says so in its first section.
- The test-first loop in step 11. Went as expected.
