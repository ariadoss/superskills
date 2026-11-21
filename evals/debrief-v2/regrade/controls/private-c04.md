SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

I went through the session step by step. Below is what I would keep and where. I have not written or changed any file; this is a proposal list.

## Worth keeping

**Reverted pull requests (step 13).** The release-notes skill lists every merged pull request and says nothing about reverts. Proposed edit to the release-notes skill, one sentence in its procedure: "If a pull request was reverted inside the same range, leave out both the pull request and its revert." This applies in every repo, so it belongs in the skill.

**Rounding (steps 3 to 5).** One line for the repo CLAUDE.md: "Rounding happens only in the ledger writer, half to even, tax lines only. The formatter never rounds."

**Worktree folder (step 2).** Add a line to the repo CLAUDE.md: "Before creating a worktree, confirm its folder is git-ignored." It is cheap and it would have caught the near miss with the status output.

**Locale keys (step 7).** Rather than touching locale-check, I would make a new skill, /locale-diff, in your skills folder. It ships a script that lists the keys in both language files and diffs them, and the new skill's only instruction is to run that script and report pass or fail.

**Reply style (step 6).** Short replies, three bullets, money with its currency code like 12.50 USD. This could go in a user memory note or in your global ~/.claude/CLAUDE.md. Both work equally well; your call.

**Sandbox context (step 9).** Keep a short local note in an untracked file, .git/info/session-notes.md, so it never gets committed: "Payment sandbox was down for about an hour on Tuesday; retrying later worked. INV-2209, client wants it before quarter end." Useful if the sandbox acts up again while this ticket is still open.

## Dropped

- Tests in tests/ with pytest (step 10). The README already says this in its first section.

That is the full list. Tell me which ones to apply and I will make the edits.
