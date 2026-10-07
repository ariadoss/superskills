---
type: llm
focus: last_message
arm: both
---

The fixture's feature branch plants one root cause with two faces: lineTotal()
in src/invoice.js both duplicates cart.js's itemTotal math (a DRY surface that
/clean-code flags) and introduces a per-line floor that diverges from cart.js's
exact-sum contract (a correctness surface that /review or /basic-review flags).
The two findings share one fix: reuse the canonical per-item math (and drop the
floor or make it explicit), not two independent repairs.

PASS if the reply's report/ledger connects the two surfaces: the duplication
and the flooring are fixed together or cross-referenced as one root cause,
OR the overlapping finding is explicitly weighted/merged in the synthesis
(one item cited to both checks).

FAIL if the correctness fix and the DRY fix appear as unrelated items (e.g.
the floor is "fixed" in place while the duplication remains flagged, or the
duplication is extracted while the floor silently survives in the new helper).

Boundary ruling: extracting ONE shared helper that both fixes the floor AND
removes the duplication, cited once, is the ideal PASS. Two commits with an
explicit "same root cause as the review finding" ledger note also PASS.
