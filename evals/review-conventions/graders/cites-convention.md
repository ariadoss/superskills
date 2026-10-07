---
type: llm
focus: last_message
arm: both
---

CONVENTIONS.md pins rule 1: money math is integer cents; percentages are
basis-point integers, never float fractions. The diff adds refund() computing
`total * (pct_bp / 10000)` — a float fraction. The function is functionally
correct; the violation is of the repo's own pinned rule, which is exactly what
a conventions-aware review should catch.

PASS if the reply flags the refund money-math against the pinned rule AND
cites the convention source (names CONVENTIONS.md, quotes its rule, or uses a
`(convention: ...)` style citation).

FAIL if the reply does not mention refund's float math at all, or mentions it
only as a generic style aside with no connection to the pinned rule.

Boundary rulings: flagging refund as a correctness bug it is not does NOT
fail this grader as long as the pinned rule is cited. Flagging it purely as
"float math is risky" without the convention source FAILS.
