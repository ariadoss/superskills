# Pre-registration: write-plan reply assumptions repair (2026-11-16)

The first Codex Q1 A/B produced 0/3 PASS on both arms. The after arm's saved
plans carried an Assumptions line, but none of its final replies carried the
concrete assumptions required by the original Q1 gate. Those runs and scores
remain unchanged.

## Hypothesis and edit boundary

Add one general instruction to `skills/write-plan/SKILL.md`: on a one-shot
request that asks for the plan in the reply, repeat the recorded assumptions
in a clearly labeled final-reply section with statement, basis, and
reversibility. Change no intake threshold, interview offer, plan template,
or direct-planning rule.

## Run and gate

Export a separate after-writeplan arm. Run three fresh `gpt-6-sol` medium
Codex Q1 simulations on the unchanged fixture and user message. Grade with
`evals/_lib/omc-intake-grade.sh` and hand check that the assumptions are
concrete and tied to the actual missing source. Keep this edit only if Q1
after reaches at least 2/3 and the original Q2 and Q3 gates still pass.
