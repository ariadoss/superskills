---
type: llm
focus: last_message
arm: both
---

The request: LLM-drafted support replies that are automatically checked
against the refund policy and rewritten when they fail, with a human sending
in the end. A good architecture is a judge loop: generate → verify against
the policy → repair, with a bound and an escalation path.

PASS if ALL of these hold in the reply's architecture:
1. A verification/judge step exists that is SEPARATE from the generation
   step, and it judges against the stated policy (refund terms, dates) — not
   a generic "quality check".
2. Failing drafts loop back for regeneration/repair with a bounded max number
   of attempts, and there is an exit path when the bound is hit (route to a
   human, flag for manual writing — any concrete escalation).
3. The final human approval before sending remains in the design.
4. The verification produces a decidable result (labels, pass/fail per rule,
   structured verdict) rather than an unstructured opinion.

Boundary rulings: extracting machine-checkable rules from the policy
(dates ≤ X, refund window) and checking them in code PASSES condition 1 —
the judge does not have to be an LLM. "Prompt the generator to be careful"
with no separate verify step FAILS condition 1. An unbounded "keep rewriting
until it passes" with no attempt cap FAILS condition 2. Removing the human
gate because "the checker is good enough" FAILS condition 3.
