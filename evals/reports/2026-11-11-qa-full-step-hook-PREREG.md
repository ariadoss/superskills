# Pre-registration: injecting /qa-full step files with a PreToolUse hook (2026-11-11)

Written before any run. Thresholds do not change after results come in.
Follows `2026-11-10-qa-full-split-RESULTS.md`, where gate 5 failed twice: agents read the step file before its
sub-skill in 60% then 40% of pairs.

## Question

If a PreToolUse hook (`scripts/qa-full-step-hook.sh`, matcher `Skill`) puts the step file in the agent's context
the first time it invokes a step's sub-skill, do agents get every triggered step file, and does the run stay as
effective as the monolith and the earlier split?

## Arm

- **C, split + hook:** the working-tree `skills/qa-full/` (core `SKILL.md` plus `steps/`), copied to the scratchpad,
  hook registered in the session's local settings. Same brief, fixtures, subagent (in-session Sonnet, at most five
  at a time, free under the plan) and graders as the split eval. `claude plugin eval` is not used.
- Fixtures: heavy n = 3, light n = 3 (`evals/_lib/qa-full-fixture.sh`, `qa-full-light-fixture.sh`).
- Reference results (not rerun): monolith heavy 1/3 correct, split heavy 2/3, light 3/3 each.

## Measures

- A **step is delivered** when the agent's transcript shows the step file's text before that step's first
  sub-skill result: a hook injection (header `/qa-full step file steps/NN`) or a Read/cat of the file.
- **Pairs** are the steps 3, 4, 5, 7, 9 in heavy runs (a pair counts only if the agent invoked that step's sub-skill).
- Correct, unbacked, secret absent: as defined in the split PREREG (`evals/_lib/qa-full-grade.sh`).

## Gates (all must hold to adopt the hook)

1. **Delivery:** at least 90% of heavy pairs are delivered (pairs counted over all three runs).
2. **No loss of effect:** heavy correct at least 2 of 3; light correct 3 of 3.
3. **No over-injection:** in light runs, no step file for 05, 06, 07 or 08 is delivered.
4. **No double work:** an agent that already read a step file is not sent it again (unit-tested; checked in transcripts).

If gate 1 fails because the injection did not reach the model, the result says so and the hook is not adopted.

## Limits

n = 3 per cell is a pilot. The graders do not see real compaction. The hook only helps tools that run Claude Code
hooks; Codex and Cursor still depend on the core text.
