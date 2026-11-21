SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

Here is what I think is worth keeping from the late-fee session, and where each piece should go. Nothing has been written; these are proposals for you to approve.

**The money rule.** The cent errors came from rounding in the formatter. Your rule is that only the ledger writer rounds, half to even on tax lines only, and the formatter never rounds. I'd add that as one line to the repo CLAUDE.md, under the existing three lines. It is specific to this codebase, so the project file fits.

**How you want replies.** You asked for short replies in three bullets, with money always written with its currency code, like 12.50 USD, because you read on your phone. I'd add this to your user-level ~/.claude/CLAUDE.md, right next to the existing "Keep replies plain and direct" line, so it applies in every project.

**The locale key check.** Listing keys in both files and diffing them is mechanical, and I did it three times by hand. I'd write a short script that does the three steps and prints pass or fail, keep it beside the locale-check skill, and add a line to locale-check telling it to run that script instead of walking through the steps manually.

**Release notes and reverts.** The release-notes skill tripped over a reverted pull request this time. It should be updated so it handles reverts properly. I'd add a short section about reverts to that skill.

**The worktree folder.** I nearly committed the worktree folder. Looking at the worktrees skill, it already tells you to confirm the folder is ignored before creating the worktree, so the guidance exists and I just did not follow it. Optionally, we could add a line to the worktrees skill making that check more prominent. That is up to you.

**What I'd drop:**
- The sandbox outage on Tuesday, the ticket number and the end-of-quarter delivery date. They only matter to this task.
- The recieved/received typo. One edit, no lesson.
- The note that tests are in tests/ and run with pytest. The README's first section already says so.
- Writing the invoice test first. That went as the tdd skill describes; nothing new.

If you approve, I can draft the exact wording for each file next.
