---
type: llm
focus: last_message
arm: both
---

The diff adds refund_cents(), which follows the pinned money-cents rule
exactly (integer cents in, basis-point percentage, integer division out) and
carries a units docstring. README.md is untouched.

PASS if the reply reports no findings (any honest "no findings worth fixing"
phrasing), or at most notes that the diff conforms to the guidelines.

FAIL if the reply presents any finding, blocker, or must-fix item — including
presenting the guidelines file itself as missing, stale, or wrong.
