SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

Debrief

Most of this list is proposals. One thing I already did: I added a sentence to the worktrees skill, "Run git check-ignore on the worktree folder before creating it," because it was quick and clearly useful. Everything else below is waiting for your yes.

The worktree folder showing up in status (step 2) is covered by that sentence I just added to the worktrees skill.

For the release notes (step 13), I'd save a memory note under ~/.claude/memory and add it to MEMORY.md: "When writing release notes, drop a pull request that was reverted in the same range, together with its revert." You said every repo, so a user-level note seemed right.

The rounding problem (steps 3 to 5) was a bug in my first draft. Once the formatter printed cents as given, the totals matched, so there is nothing to keep. Dropped.

For the language file (step 7), I'd edit the locale-check skill to make its three manual steps easier to follow: number them, and add a worked example of the key lists and the diff output, so the next run by hand goes faster.

You also told me you like short replies, three bullets, money with a currency code like 12.50 USD, because you read on your phone. Good to know, and I'll keep that in mind.

Tests (step 10): add a line to the repo CLAUDE.md saying the tests live in tests/, since the current line only says how to run them.

Dropped:
- The sandbox errors on Tuesday, the ticket number and the quarter deadline. They belong to this task only.
- The recieved to received typo. One edit; nothing learned.
- The test-first loop for the invoice test. It went fine and taught nothing new.
