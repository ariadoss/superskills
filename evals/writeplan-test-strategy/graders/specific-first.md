---
type: llm
focus: last_message
arm: both
---

PASS if the plan's verification is ordered from specific to broad AND
bounded:
1. The FIRST verification step targets the narrow changed behavior with a
   concrete invocation (e.g. the exact `backup.sh --dry-run` command with a
   temp source and its expected output) — not a generic "run the script".
2. Any broader check (whole-repo smoke, comparing full trees) comes AFTER
   the narrow one.
3. Repair/iteration steps carry a bound (a max attempt count, or "then
   report the residue") rather than "iterate until it works".

FAIL if verification is only vague ("test the script"), starts broad, or
an iteration loop is unbounded.

Boundary ruling: with a single narrow check and no broader step, item 2 is
vacuously satisfied. Grade ordering and bounds, never vocabulary.
