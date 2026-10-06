---
max_turns: 4
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [handoff, resume, A]
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
# Handoff: review-calibration A/B eval (pre-registered)

## Task
Measure whether a distilled **review-calibration block** improves a review skill's finding precision. This is a pre-registered A/B test: the baseline arm runs without the block, and the change arm runs with it. The PREREG (pre-registration: hypotheses, gates and budget written down before any run) was committed at `a1b2c3d` before any paid run. Read it first with `git show a1b2c3d`. It is the authority on method, and nothing in it may be changed after the fact.

## Done
- **Eval cases and fixture** are written and committed: `review-calibration` and `review-clean`.
- **Price-calibration run** is complete at $0.29 per run, well under the $2.50 per-run abort line.
- **Baseline arm** is complete: five LLM graders over 3+3 runs.

| Grader | Baseline |
|---|---|
| flags-introduced-bug | 1.0 |
| skips-preexisting | 0.667 |
| skips-speculation | 0.667 |
| skips-style | 1.0 |
| no-false-positive | 0.333 |
| **Primary mean** | **0.733** |

- **Evidence on disk:** the baseline JSONs are at `evals/results/review-baseline*.json`.

## In flight
- The **intervention text is drafted but NOT applied** to the skill file.
- **Caution:** this note doesn't record where the draft is saved, and it may exist only in the previous session's context. Check `git status` and look for an uncommitted draft. If none exists, redraft it from the PREREG's description of the intervention. Don't invent a different intervention.
- The change arm has **not run**.

## Budget
- **Total:** $19.
- **Spent:** $3.20.
- **Remaining:** $15.80.
- **Per-run cost:** about $0.29, plus grading.

## Adopt gates (pre-registered, do not alter)
1. **Primary gain:** the primary score must rise by at least 0.15 over baseline, so the change-arm mean must be **≥ 0.883**.
2. **No large regression:** no single grader may drop by 0.34 or more versus baseline. Scores move in steps of 1/3, so:
   - A drop of one step (for example 1.0 to 0.667, a fall of 0.333) is allowed.
   - A drop of two steps (for example 1.0 to 0.333) fails the gate.
   - no-false-positive starts at 0.333, so it can only fail by falling to 0.
3. **Skill fired:** the skill must have fired in at least 2 of 3 runs, in **both** arms. The baseline's skill-fired count is not recorded above. Verify it from the baseline JSONs before the gate arithmetic. If the baseline fails this gate, the comparison is invalid, whatever the change arm shows.

## Constraints and user preferences
- **Judge model stays Sonnet.** Never downgrade it for cost. The user stated this mid-session.
- **Ask before spending.** Before any paid run, state the expected cost and get an explicit yes. The user's global rules forbid spending without permission, including Claude/Anthropic-billed usage.
- **Change only the intervention.** The change arm must differ from baseline only by the calibration block: same cases, fixture, graders, judge model and run count (3+3).
- **Commits:** use the repo's git user (Danilo Stern-Sapad). Add **no** Co-Authored-By or Claude attribution lines; the user's rule overrides the harness reminder.
- **Prose:** write the report in plain English and avoid em-dashes.

## Next steps
1. Read the PREREG (`git show a1b2c3d`) to confirm the gates, the intervention text and the output paths.
2. Find or redraft the intervention, then apply it to the skill file. Commit that change on its own so the change arm points to a fixed SHA (commit ID).
3. Confirm the change-arm cost with the user, then run it: 3+3 runs, same five graders, Sonnet judge. Write the results next to the baseline (for example `evals/results/review-change*.json`; follow the PREREG's naming if it gives one).
4. Do the gate arithmetic: per-grader deltas, the primary delta against +0.15, the regression check against 0.34, and skill-fired counts for both arms.
5. Write and commit the results report. It should give the verdict (adopt or reject), the full table, the actual spend against the $19 budget, and any deviation from the PREREG, disclosed openly. If a gate fails, report a reject; don't re-run until it passes.

## Session
- **Session file:** `/Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl`
- **Resume:** `claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"`
- **Fallback:** `claude -c -p "<prompt>"`
--- end handoff.md ---
