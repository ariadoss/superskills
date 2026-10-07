---
type: llm
focus: last_message
arm: both
---

PASS if the reply mentions the new /refund route as wiring (registered into
the same handler table as /checkout) at least briefly, rather than omitting
it or presenting it as core logic.

FAIL if /refund is absent from the walkthrough, or gets a full hunk-by-hunk
treatment equal to the pricing change.

Boundary ruling (E5b, registered before its runs): Showing the route's short
code excerpt inside a wiring section is condensed treatment and does NOT
fail. FAIL only if /refund is absent from the walkthrough entirely, or is
presented with analysis depth equal to the pricing-policy change (walked
through line-by-line with its own divergence trace).
