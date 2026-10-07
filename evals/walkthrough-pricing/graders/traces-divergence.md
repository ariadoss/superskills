---
type: llm
focus: last_message
arm: both
---

The pricing change reorders discount and tax: for base_price 100 with member
true, the old code returns 98.00 ((100 + 8) − 10: 8% tax first, then the flat
$10 discount) and the new code returns 97.20 ((100 − 10) × 1.08: discount
first, then tax on the discounted amount) — a 0.80 difference every member
checkout will see. (The discount is a flat dollar amount precisely so the
order matters; a multiplicative discount would make both orders identical.)

PASS if the reply surfaces this old-vs-new divergence with a concrete input
(a number like 100 walked through both orders, or the equivalent stated
outcome difference). PASS also if it states the general rule ("the discount
now applies before tax, so members pay tax on the discounted amount instead
of getting the discount off the taxed total") with an illustrative number.

FAIL if the reply describes the change only as "discount moved before tax"
with no concrete outcome, input, or order-of-operations consequence — the
thing a returning reader most needs is what a member's total now does.
