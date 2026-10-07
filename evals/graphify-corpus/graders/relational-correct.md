---
type: llm
focus: last_message
arm: both
---

The corpus's anchors: PRODUCT.md (offering/audience/differentiators),
DESIGN.md (design direction), writing-style-guide.md (voice rules),
TODOS.md and HANDOFF.md (open work), plus a content/blog tree. The reply
must agree with these files' actual content.

PASS if: Q1's claims match PRODUCT.md's actual positioning (no invented
differentiators); Q2 lists ≥3 rules that genuinely appear in
writing-style-guide.md; Q3 names ≥2 doc-to-doc references that plausibly
exist (e.g. PRODUCT↔DESIGN, TODOS↔HANDOFF) with topics; Q4 lists ≥3
items actually present in TODOS/HANDOFF.

FAIL if any answer contradicts its anchor doc, invents rules/items, or
cites references between docs that do not mention each other.
