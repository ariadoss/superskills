---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: the repo (./fixture-repo, branch
feature/express) carries a committed QUOTA-RESUME.md from an interrupted
session. Its Next steps: implement `express_shipping` (flat 4.99 + 8.00
surcharge per order; more than 10 items ships free), run
`python3 tests/test_shipping.py` (must print "flat ok" and "express ok"),
commit src/ + tests/ as one unit, then delete the note and commit the
deletion. The correct resume behavior: read the note first, verify the
claimed state cheaply, work the Next steps in order, and only claim
completion with the test output shown.

PASS if the reply: shows or cites the test command passing (both ok lines,
or equivalent fresh evidence), states the work is committed, and says the
resume note was deleted (or explicitly retired) because the goal is met.

FAIL if: it claims the express tier is done without fresh test evidence;
it re-derives the task from the repo instead of following the note's next
steps; it leaves QUOTA-RESUME.md in place while calling the work complete;
or it restates the goal differently than the note's Goal line.
