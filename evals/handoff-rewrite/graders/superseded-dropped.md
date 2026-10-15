---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: in the earlier handoff-7c1d2f.md, "In
flight" listed the express tier (it has since landed in a commit) and
"Context" recorded reading src/calc.py in its flat-only shape (that content
was rewritten by the same commit, so the read is obsolete).

PASS if the final note: lists the express tier under Done (with its commit
hash or an equivalent anchor), NOT under In flight; carries In flight
content matching the actual working tree (src/rates.py stub); and does not
list the pre-rewrite read of src/calc.py in Context.

FAIL if: the express tier remains in In flight; the superseded
"read src/calc.py (flat-only version)" line survives in Context; or the
note's state contradicts `git log`/`git status` of the fixture.
