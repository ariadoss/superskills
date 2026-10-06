---
max_turns: 4
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [handoff, resume, C]
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
# Handoff: A/B eval of a distilled review-calibration block for review-skill precision @ 2026-10-06

## Session
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"
fallback: claude -c -p "<prompt>"

## Goal
Run the change arm and apply the gates pre-registered in PREREG (commit a1b2c3d) to decide adopt or reject. Then commit a results report.

## Done
- PREREG was committed at a1b2c3d before any run. It fixes the cases, the graders and the adopt gates.
- Eval cases and fixture are written and committed: `review-calibration` and `review-clean`. The session state did not record their commit hash.
- Price-calibration run is complete: $0.29 per run, under the $2.50 per-run abort line.
- Baseline arm is complete: five LLM graders over 3+3 runs. Results are in `evals/results/review-baseline*.json`.
  - Primary mean 0.733, which is the average of the five grader scores.
  - flags-introduced-bug 1.0, skips-preexisting 0.667, skips-speculation 0.667, skips-style 1.0, no-false-positive 0.333.

## In flight
- **Intervention text (the distilled review-calibration block):** drafted but NOT applied to the review skill file. The session state did not record where the draft lives or the skill file's path. Unverified.
- **Change arm:** not run.
- **Baseline skill-fired count:** the session state did not record whether the skill fired in at least 2 of 3 runs. Unverified.

## Next steps
1. Find the drafted intervention text and the target skill file: run `git status`, `git log --oneline a1b2c3d..HEAD` and `git show a1b2c3d`. PREREG should name the skill file and the run command.
2. Apply the intervention text to the review skill file, unchanged. Commit it alone so the change arm has a hash to cite.
3. Check skill-fired in the baseline JSONs: `ls evals/results/review-baseline*.json`, then inspect each file. The gate needs at least 2/3 in both arms.
4. Run the change arm with the same command, cases, run counts (3+3) and judge model as the baseline, per PREREG. Write the output to `evals/results/review-change*.json`. If a single run costs more than $2.50, stop.
5. Do the gate arithmetic against the baseline numbers listed under Done.
6. Write and commit the results report. Include the verdict, per-grader deltas and total spend.

## Verify
- Every pre-registered gate must pass to adopt:
  - **Primary:** change mean minus 0.733 must be at least +0.15, so the change mean must be ≥ 0.883.
  - **No grader regression:** no grader may fall by 0.34 or more from its baseline. With 3 runs per case, a one-run drop is 0.333 and stays under the limit. A two-run drop (0.667) is a regression.
  - **Skill-fired:** at least 2/3 in both arms.
- `git log` shows the results report commit.

## Do not redo
- The baseline arm. Its JSONs exist, and it must not be re-run for a better draw.
- Price calibration ($0.29 per run is already measured).
- Writing the eval cases or fixture, or editing PREREG. The gates are fixed at a1b2c3d.

## Context
- Budget: $19 total, $3.20 spent, $15.80 left.
- User preference: the judge model must stay Sonnet. Never downgrade it to save money.
- Same arms, same cases, same judge: the only difference between baseline and change is the intervention block in the skill file.
--- end handoff.md ---
