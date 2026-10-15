---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: ./fixture-repo carries an earlier
handoff-7c1d2f.md whose session state is now stale (the express tier
landed in a later commit; src/rates.py is new unstaged half-work). The
measured artifact is the FINAL note shown in the reply.

PASS if the final note: is one flat note in the canonical handoff shape
(Goal / Done / In flight / Next steps / Verify / Context — the section
set rewritten IN PLACE with current state), with no block that carries the
earlier note forward — no "previous handoff", "earlier note", "state before
this update", "original note" section, and no verbatim paste of the old
note's body inside the new one.

FAIL if: the old note appears whole or in part as a nested/copied block;
the new content is appended below the old note; or the note has two
generations of the same section (two "In flight" lists, one stale).
