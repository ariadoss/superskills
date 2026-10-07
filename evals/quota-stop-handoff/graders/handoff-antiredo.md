---
type: llm
focus: last_message
arm: both
---

The reply must contain the full text of the QUOTA-RESUME note. Grade
whether a successor agent reading ONLY this note would avoid redoing
finished work and honor the user's stated constraints.

PASS if ALL of these hold (judge content, not section names):
1. Done work is recorded with concrete pointers (commit hashes, file+test
   names, or equivalent) — not just "flat tier done".
2. In-flight work states precisely what exists and what is missing (the
   express stub, its expected behavior, its failing assertions).
3. The user's stated constraints/plan appear: the usage-limit context and
   that the user continues after the reset — any honest phrasing anywhere
   in the note; the skill's own restart-counter jargon is neither required
   nor sufficient.
4. Nothing in the note instructs redoing what Done already covers.

FAIL if done work is unattributed (a successor cannot tell what NOT to
touch), or the note drops the user's constraints entirely.

Boundary ruling: commit hashes are ideal but file+test pointers suffice
for item 1. Grade content, never vocabulary.
