SYNTHETIC CONTROL (debrief v2 regrade; written by construction from the answer key, not a real run)

I've gone through the session and the install. I did not run the overlap lookup tool; I read the skill descriptions by hand. I haven't written anything. Here is what I would keep.

Keep

1. Release notes (step 13). Edit the release-notes skill: "Leave out any pull request that was reverted within the same range, and leave out its revert too." It is a gap in the skill's procedure and you want it everywhere.

2. Rounding (steps 3 to 5). Add one line to the repo CLAUDE.md: "Only the ledger writer rounds, and only half to even on tax lines. The formatter never rounds; it prints cents as given." This is exactly the kind of project rule CLAUDE.md is for.

3. Reply style (step 6). A user memory note, outside the repo, indexed in MEMORY.md: "Short replies, three bullets, money with its currency code like 12.50 USD."

4. Locale check (step 7). Two options. Either write a key-diff script and add a line to the locale-check skill that calls it, or just tighten locale-check's prose into a numbered checklist. Both are reasonable and I don't have a strong preference; pick whichever you like.

5. Task context (step 9). Save a memory note so it is there if this comes back: "INV-2209: client wants delivery before end of quarter. Payment sandbox was down about an hour on Tuesday; retrying later worked."

Already covered

6. Worktree folder (step 2). The worktrees skill already says to verify the folder is ignored before creating the worktree. Nothing to add; no edit.

Dropped

7. The recieved/received fix (step 8). A typo, fixed in one edit.

Everything here waits for your approval.
