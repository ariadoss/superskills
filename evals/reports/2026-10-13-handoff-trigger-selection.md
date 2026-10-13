# /handoff trigger selection eval (2026-10-13)

Question: after the rewording (per-session `handoff-<session-id>.md`; fire only on manual
invocation or a hook trigger at 90% context, 90% five-hour window, 95% weekly window),
does a model still pick `/handoff` when it should, and leave it alone when it should not?

## Method

- Free in-session method: one Sonnet subagent per (case, arm, repetition), no tools, told to
  name the first skill it would invoke as JSON. No billed `claude plugin eval` run.
- Arms: BEFORE = description at git HEAD; AFTER = description in the working tree. Both saw the
  same nine distractor skills (quota-resilience, context-save, context-restore, debug, review,
  ship, document-generate, spec, tdd).
- Grader: exact match against the answer key, so there is no LLM judge to calibrate.
- Positive class: handoff fires. A false positive is handoff firing where it should not.
- Gates were written before any run: AFTER fires on at least 9/10 gated positives, false-fires
  on at most 1/14 gated negatives, and false-fires no more than BEFORE.

## Cases (14)

| id | kind | input | expected |
|---|---|---|---|
| P1 | positive | "Write a handoff for the next session so it can pick this up cheaply." | handoff |
| P2 | positive | "/handoff" | handoff |
| P3 | positive | hook text: context window 91% (threshold 90%) + "keep going with the refactor" | handoff |
| P4 | positive | hook text: 5-hour window 92% (threshold 90%) + "fix the failing test" | handoff |
| P5 | positive | hook text: weekly window 96% (threshold 95%) + "update the README table" | handoff |
| N1 | negative | session start: "Fix the failing test in tests/foo.bats" | not handoff |
| N2 | negative | session start: "start a new feature: retry logic for the uploader" | not handoff |
| N6 | negative | statusline shows context 34%, 5-hour 12%, weekly 40% + "continue the migration" | not handoff |
| N7 | negative | "Write a handoff document for the new engineer ..." (human doc, near miss) | not handoff |
| N8 | negative | "Save my working context so I can come back to it." | not handoff |
| N9 | negative | "Good morning. Review the diff on the current branch." | not handoff |
| N10 | negative | harness: usage limit hit, session being cut off | not handoff |
| N4 | borderline, ungated | "I'm about to take a break. Summarize what we got done." | reported only |
| N5 | borderline, ungated | "I'm running low on usage for the week, keep that in mind." | reported only |

## Results

| arm | gated positives fired | gated negatives false-fired | N4 | N5 |
|---|---|---|---|---|
| BEFORE (rep 1 only) | 5/5 | 0/7 | fired | fired |
| AFTER (2 reps) | 10/10 | 0/14 | no | no |

Gates: positives 10/10 (>= 9) pass; false fires 0/14 (<= 1) pass; AFTER <= BEFORE (0 vs 0) pass.
The runs that did not fire on the negatives picked sensible neighbors: debug, spec, review,
document-generate, context-save, quota-resilience, or no skill.

## What this does and does not show

- The reworded description does what was intended on the borderlines: the old text fired on a
  user merely mentioning a limit or a break; the new text does not.
- BEFORE did not false-fire on ordinary session-start prompts (N1, N2, N9) in this harness. So
  the description alone does not reproduce the Codex symptom of `/handoff` running when a
  session starts. The Claude Code half of that symptom was real and is fixed in the hook (never
  nudge before the session's first assistant reply; account windows were previously read
  regardless of session). The Codex cause is still open: Codex has no such hook, and this eval
  simulates skill selection with a prompt, not Codex's actual matcher.
- Small n: counts are the signal, no significance is claimed.

## Deviations from the plan

- BEFORE ran one repetition, not two, and the borderlines ran once per arm, to limit plan usage
  (each subagent costs about 47k tokens). The BEFORE false-fire count is therefore out of 7,
  not 14. The AFTER <= BEFORE gate is read at that smaller n.

## Deterministic coverage (bats, runs in `./tests/run.sh`)

- `tests/handoff-trigger-hook.bats`: per-trigger thresholds (context 90, five-hour 90, weekly
  95; 89/94 stay quiet), once-per-window re-arm, expired windows, no nudge before the first
  assistant reply, trigger independence, a bad threshold disables only its own trigger,
  statusline-to-hook end to end, and the nudge names `handoff-<session-id>.md`.
- `tests/handoff-session-ref.bats`: per-session filename from hook id, `CLAUDE_CODE_SESSION_ID`,
  Codex thread id, unique timestamp fallback, sanitized ids.
