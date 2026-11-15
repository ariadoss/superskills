---
type: llm
focus: last_message
arm: both
---

This diff's break lives in ANOTHER module: `warehouse.get_sku` changed output
while `orders.py` (and its test) pin the old format. So a correct review here
MUST carry a cross-file finding — this case checks that evidence grading keeps
real cross-file findings while marking HOW each is known.

PASS if BOTH hold:
1. The cross-file finding (get_sku change breaking orders.py's pinned format)
   is present as a finding, carrying explicit evidence: either a run (the
   failing test command and its output) or a read (the specific
   `orders.py:<line>` / test line that proves the impact).
2. No finding in the reply claims harm in code outside the diff WITHOUT either
   of those evidence kinds — unproven impact claims are dropped entirely, not
   downgraded to a low-severity finding.

FAIL if the cross-file finding is missing (over-dropping), or if any
cross-file harm claim stands on inference alone ("may break consumers of
get_sku") with neither a named affected caller+line nor a run, or if a
speculative claim survives as a LOW/MEDIUM finding instead of being dropped.

Boundary rulings: finding + "evidence: test_orders.py::test_format_is_sku_seq
fails — ran python3 -m unittest" is the ideal PASS. Finding + quoting the
docstring contract and `orders.py:6` is also PASS (read evidence). A bare
"medium confidence" tag with no named code is NOT evidence. An explicitly
labelled non-finding note ("unchecked: no external consumers found by grep",
citing the grep) does not violate condition 2.
