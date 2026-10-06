---
max_turns: 4
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [handoff, resume, B]
---

You are a fresh agent with no memory of any prior session. Below is
the handoff.md the previous session left for you. Read it and answer, in
your reply, each of these five questions with specifics:
1. What is the task's definition of done, and what proves it?
2. What is already finished (with its commit hashes / file:line)?
3. What is the single next action, as an exact command?
4. What must you NOT redo, and which known-dead approaches were tried?
5. How would you resume the original session (harness + exact command)?

--- handoff.md (verbatim) ---
# Handoff — A/B eval: does a distilled review-calibration block improve review-skill finding precision @ 2026-10-06

## Session
~~~
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"
fallback: claude -c -p "<prompt>"
~~~

## Goal
Run the change arm, apply the three pre-registered adopt gates to baseline vs change, and commit the results report with an adopt or reject verdict.

## Done
- PREREG committed before any paid run: `a1b2c3d`.
- Eval cases and fixture written and committed: `review-calibration`, `review-clean`. The commit hash was not captured in session state. Find it with `git log --oneline -- evals/`.
- Price-calibration run finished: $0.29/run, well under the $2.50/run abort line.
- Baseline arm finished: five LLM graders over 3+3 runs. Output is in `evals/results/review-baseline*.json`.
  - Primary mean **0.733**
  - flags-introduced-bug 1.0
  - skips-preexisting 0.667
  - skips-speculation 0.667
  - skips-style 1.0
  - no-false-positive 0.333

## In flight
- **Intervention text:** a draft exists but has **not** been applied to the review skill file. Session state does not record where the draft lives or the skill file's path. Find both before editing.
- **Change arm:** not run.
- **Unverified:** the baseline skill-fired rate. Gate 3 needs at least 2/3 in both arms, and nobody has checked the baseline side yet.

## Next steps
1. Recover the pre-registered run procedure, skill path and grader config from the PREREG commit: `git show a1b2c3d`
2. Check baseline skill-fired before spending anything. If the baseline is under 2/3, gate 3 already fails, so stop and report: `ls evals/results/review-baseline*.json` and then read the skill-fired field in each.
3. Paste the drafted calibration block into the review skill file at the location PREREG specifies. Change nothing else.
4. Run the change arm with the same cases (`review-calibration`, `review-clean`), the same 3+3 runs, the same five graders and the **sonnet** judge, using the invocation from step 1. Write output to `evals/results/review-change*.json` to mirror the baseline naming.
5. Compute the gates (see Verify).
6. Write the results report and commit it together with the change-arm JSONs. The verdict is adopt only if all three gates pass. Otherwise it is reject, as pre-registered.

## Verify
- `ls evals/results/review-baseline*.json evals/results/review-change*.json`: both arms exist.
- Gate arithmetic, which must hold together:
  - **Primary:** change mean ≥ 0.733 + 0.15 = **0.883**.
  - **No regression ≥ 0.34 on any grader.** With three runs, scores move in steps of 0.333. A one-step drop (0.333) passes and a two-step drop (0.667) fails. So flags-introduced-bug and skips-style must stay ≥ 0.667, and skips-preexisting and skips-speculation must stay ≥ 0.333. no-false-positive cannot regress by 0.34 or more from 0.333.
  - **Skill-fired:** ≥ 2/3 in baseline and in change.

## Do not redo
- Baseline arm: it is complete. Re-running it spends budget and breaks the pre-registered comparison.
- Price-calibration run: done at $0.29/run.
- Eval cases and fixture: committed. Do not edit them, because both arms must use identical inputs.
- PREREG `a1b2c3d`: frozen. Do not move the gates or thresholds after seeing results.

## Context
- **Budget:** $19 total, $3.20 spent, **$15.80 left**. The abort line is $2.50/run.
- **User preference stated this session:** the judge model stays **sonnet**. Never downgrade it to save money.
- **Gates (pre-registered):** primary ≥ +0.15, no grader regresses by ≥ 0.34, skill-fired ≥ 2/3 in both arms.
- **Baseline weak spot:** no-false-positive is at 0.333. That is the precision dimension the calibration block targets.
--- end handoff.md ---
