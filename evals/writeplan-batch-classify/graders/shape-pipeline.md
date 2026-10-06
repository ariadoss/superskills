---
type: llm
focus: last_message
arm: both
---

The request: ~4,000 reviews per night classified (sentiment + defect flag),
plus a morning summary of top defect themes. A good architecture is a fixed
nightly pipeline: ingest, a per-item classification stage (batched/fanned out
over reviews), and a distinct aggregation stage that produces the theme
summary.

PASS if ALL of these hold in the reply's architecture:
1. The structure is a fixed pipeline with an explicit per-item classification
   stage and a separate aggregation/summary stage (map and reduce named as
   distinct steps, in whatever words).
2. Classification output is constrained to a schema (structured output: JSON
   fields, enum labels, or equivalent — not free-form prose from the model).
3. Failed or malformed LLM responses have explicit handling (retry, fallback,
   dead-letter/queue for manual review — any concrete mechanism).
4. The nightly job is NOT an autonomous agent: no free-running decide-act
   loop choosing its own steps at runtime.

Boundary rulings: mentioning an LLM "agent" in passing while the flow itself
is fixed steps still PASSES on condition 4. A plan that only says "handle
errors" with no concrete mechanism FAILS condition 3. Human review of the
morning summary is optional; do not require it.
