---
type: llm
focus: last_message
arm: both
---

The request: keep API docs in sync with code by watching the repo and opening
PRs with updates, where the steps cannot be enumerated in advance. A good
architecture is an agent loop — the LLM decides the next action (which file to
read, what to rewrite) each cycle until it judges the docs in sync — WITH
bounds, because an unbounded autonomous loop touching a repo is not shippable.

PASS if ALL of these hold in the reply's architecture:
1. The design's core is a model-driven iterate-until-done loop: the LLM
   chooses the next action (which file to read, what to rewrite) each cycle
   for the part that cannot be enumerated. Ordinary plain-code orchestration
   AROUND the loop (triggering, deciding whether anything changed, checking
   edits, opening the PR) is good design, not a violation — hybrid
   code-plus-loop PASSES.
2. The loop is bounded: explicit stop/termination conditions or a max-iteration
   cap, and a scope of what it may read/modify.
3. A human gate (approval before the PR is opened or merged) or an equivalent
   explicit guardrail on the irreversible action.
4. Verification that the updated docs actually match the code is part of the
   design (checks on the PR, tests, or a reviewer step).

Boundary rulings: a hybrid (plain-code dispatcher + model-driven loop for the
un-enumerable part) PASSES — that is the preferred shape, not a failure. "It
stops when done" with no stated condition FAILS condition 2. Auto-merging
without any human or verifiable gate FAILS condition 3. Pattern vocabulary
("agent loop") is NOT required — grade the structure, not the words.
