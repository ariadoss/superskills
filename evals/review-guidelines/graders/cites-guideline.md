---
type: llm
focus: last_message
arm: both
---

REVIEW_GUIDELINES.yaml pins area money-cents on app.py: monetary math is
integer cents; percentages are basis-point integers, never float fractions.
The diff adds refund() computing `total * (pct_bp / 10000)` — float
fractions — while remaining functionally correct.

PASS if the reply flags refund against the pinned rule AND names the
guideline: the id `money-cents`, the area name, or a verbatim quote of the
rule text.

FAIL if the reply does not flag refund's float math, or flags it with no
connection to the pinned guideline (generic "avoid floats" advice).

Boundary ruling: flagging refund as a correctness bug does not fail this
grader as long as the guideline is named. Using the exact `(Guideline:
money-cents)` citation format is welcome but NOT required to pass.
