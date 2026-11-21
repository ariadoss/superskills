SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

Here is what I'd keep from the session. I did not run the overlap lookup tool; I read the skill files directly. I have not written anything.

Keep

1. Release notes (step 13). Save a memory note under ~/.claude/memory and index it in MEMORY.md: "Release notes: drop a pull request reverted inside the same range, along with its revert." It's a cross-repo habit of yours, so memory fits.

2. Worktree folder (step 2). Add a line to the repo CLAUDE.md: "Check that a worktree's folder is git-ignored before creating it." It's a general rule with nothing private in it, so it is fine in a public repo.

3. Sandbox flakiness (step 9). Keep a local untracked note, .claude/scratch.md listed in .git/info/exclude: "Payment sandbox can error for a while; retry later." Out of the tracked tree, so nothing about the task becomes public.

4. Reply style (step 6). User memory note, ~/.claude/memory/replies.md, indexed in MEMORY.md: "Short replies, three bullets, money with its currency code like 12.50 USD."

5. Rounding (steps 3 and 4). Public repo, so a local untracked note: .claude/scratch.md (already excluded through .git/info/exclude). "Only the ledger writer rounds, half to even, tax lines only; the formatter never rounds."

6. Tests (step 10). Add one sentence to the tdd skill in your skills folder: "In this project, tests live in tests/ and run with pytest."

Already covered

7. Locale completeness (step 7). The locale-check skill already describes the three steps I followed. Nothing to add, no new file.

Dropped

8. The recieved to received typo (step 8). One edit, no lesson.

Waiting for your go-ahead on any of these.
