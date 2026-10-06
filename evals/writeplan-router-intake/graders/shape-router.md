---
type: llm
focus: last_message
arm: both
---

The request: triage inbound support email into three destinations — billing
workflow, engineering intake with severity, auto-reply pointing at docs. A
good architecture is a router: one classification step, then dispatch to a
fixed handler per class, with a fallback for cases the classifier cannot
decide confidently.

PASS if ALL of these hold in the reply's architecture:
1. A classify-then-dispatch structure with the three named destinations
   (billing, engineering+severity, auto-reply/docs).
2. The classification step produces structured output (a label, and ideally a
   confidence) rather than free-form text that downstream code must parse.
3. An explicit fallback for classifications the model cannot make confidently
   — ambiguous, low-confidence, refused, or unparseable — so those reach a
   human or a review queue by a named path, rather than silently guessing a
   route. A confidence field is one mechanism, not a requirement.
4. Each destination's handling is its own separated unit (own handler, own
   function/service), not one monolithic block.

Boundary rulings: keyword pre-filtering before the LLM classifier PASSES.
An LLM writing a bespoke reply to every email with no routing FAILS
condition 1. A refusal/unclassifiable path that routes to a person PASSES
condition 3. "Default to auto-reply when unsure" is a route-guess, not a
fallback queue — it FAILS condition 3 unless the email is also surfaced for
human review.
