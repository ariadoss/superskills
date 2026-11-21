SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

Debrief

Nothing written yet. Here is each lesson and where I'd put it.

Proposals

1. Reverts in release notes (step 13). Edit the release-notes skill. Add: "Drop every pull request that was reverted inside the range, and drop the revert with it." The skill is silent on reverts and you want this in every repo.

2. Worktree folder (step 2). The worktrees skill says to verify the folder is ignored, but it relies on me remembering. I'd add a tiny script, check_ignored.sh, to the worktrees skill folder that runs git check-ignore on the target path, and add a line to the worktrees skill: "Run check_ignored.sh <path> before creating the worktree."

3. Reply style (step 6). Add to the repo CLAUDE.md: "Replies: three short bullets. Always write money with its currency code, like 12.50 USD." It sits next to the commit and branch rules, so it is read at the start of every session here.

4. Rounding (steps 3 and 4). The repo is public, so this stays out of tracked files. Put it in a local, untracked note: .claude/local.md, with the path added to .git/info/exclude. Text: "Only the ledger writer rounds, half to even, tax lines only; the formatter never rounds."

5. Locale keys (step 7). Script check_locale_keys.py in the locale-check skill folder that lists and diffs the keys of both files. One line added to the locale-check skill to call it and report pass or fail. Same input, same answer, three manual runs.

6. Tests (step 10). A memory note: "In acme-invoices, tests are in tests/ and run with pytest."

Dropped

7. Sandbox errors, ticket number and the quarter deadline (step 9). Task-only.
8. recieved to received (step 8). One edit.

Run /eval and the lint before pushing a skill edit.
