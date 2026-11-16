# Pre-registration: deep-interview criterion format repair (2026-11-16)

Round 1 of the Codex Q4 case returned one question and a pending-approval
spec in all three runs, but the spec's checkable criteria began with nouns or
command names, rather than the action verbs required by the original
pre-registration. The strict script score was 0/3. This report preserves that
score; round 2 is a new comparison against the unchanged round-1 arm.

## Hypothesis and edit boundary

Add one general instruction to `skills/deep-interview/SKILL.md`: every
acceptance criterion starts with a concrete action verb and states an
observable result. Change no thresholds, interview scoring, question count,
or approval language. The prompt names no fixture-specific details.

## Run

Use the same `gpt-6-sol` medium-effort, two-turn Codex protocol and Q4 fixture
from `2026-11-16-omc-codex-PREREG.md`, with three fresh runs. Export the new
skill body to a separate arm; do not overwrite round 1. The scripted answer
stays identical. Grade with `evals/_lib/omc-deepinterview-grade.sh` and hand
check that the first question targets the missing success criterion.

## Gate

Keep the repaired deep-interview skill only if at least 2/3 runs satisfy all
original Q4 requirements: one question at the weakest dimension, no early
file write, exactly one pending-approval spec, action-verb checkable criteria,
and no unrelated file edits. Record script and human labels separately.
