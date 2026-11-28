# Eval report: suite-stamp skill wording (OLD a348d9a vs NEW HEAD)

Thresholds were fixed beforehand in `2026-11-21-suite-stamp-skills-PREREG.md`. Nothing was changed after results.

## Method and scope

In-session Sonnet subagents, no `claude plugin eval` spend. Each agent got a fresh fixture repo and a prompt pointing at the skill file (OLD or NEW tree). Graders are deterministic scripts (`evals/_lib/suite-stamp-eval.sh`) over fixture state and the agent's final message. There is no LLM judge, so the check on the grader is an answer key labeled by a human read of the runs.

Dimension (binary): did the agent obey the rule the change added. Positive class: FAIL (the agent disobeyed).

Scope limits: these are step probes. daily-qa and qa-full agents ran only the step under test and stopped, so this is not a full `/qa-full` run. n is small (2 per cell).

## Eval set

- Positive scenarios (the new rule should change behavior): cc-P, tc-P, dq-P, fb-P, qf-P. Two runs each, on both OLD and NEW: 10 per side.
- Negative controls (the new rule must not fire), NEW only: dq-N1 (dirty tree), dq-N2 (explicit window), dq-N3 (HEAD differs from stored sha), dq-N4 (timestamp-only file), fb-N (no stamp yet). Two runs each: 10 runs.
- Total 30 runs.

## Results against the thresholds

| Gate | Threshold | Result | Verdict |
|---|---|---|---|
| 1. Positives, NEW, pooled | >= 8/10 | 10/10 | pass |
| 2. Positives, OLD, pooled | change credited only if <= 5/10 | 0/10 | pass, the change is credited with movement |
| 3. Negative controls, NEW | 10/10 | 10/10 | pass |
| 4. No scenario at 0/2 NEW | none | lowest is 2/2 | pass |

OLD failure class: every OLD run of cc-P, tc-P and fb-P ran the whole suite (`FULL`). OLD dq-P never skipped. OLD qf-P either asked a whole-suite question or lacked the closing sentence. NEW removed all of these.

## Grader check (answer key)

18 runs labeled by a human read of the final messages and fixture state, before looking at grader output. They span every scenario and both sides (7 NEW positives, 6 OLD positives, 5 NEW negatives). Positive class: FAIL.

| Metric | Value |
|---|---|
| TP / TN / FP / FN | 6 / 12 / 0 / 0 |
| TPR (recall) | 1.0000 |
| TNR (specificity) | 1.0000 |
| accuracy | 1.0000 |
| precision | 1.0000 |

Bias: none (judge FAIL where human PASS: 0/12; judge PASS where human FAIL: 0/6). Gate was accuracy >= 0.90 with TPR and TNR >= 0.85: pass. With 6 FAIL labels, these are counts, not tight rates.

## Grader bug found and fixed before measurement was final

The first grading pass failed both NEW dq-P runs even though the agents had skipped correctly. The grader counted the one-line report file the agent wrote (`daily-qa-reports/`) as extra work. Fix: ignore untracked files under `daily-qa-reports/` in `skip_taken()`. All runs were re-graded with the fixed grader, and `tests/suite-stamp-eval.bats` still passes 12 of 12. The key labels were made from the transcripts, not from the grader, so the fix is not circular.

## Not covered

- A real end-to-end `/qa-full` or `/daily-qa` run, and real hook behavior on a live merge (covered by `tests/suite-stamp.bats` instead).
- n=2 per cell cannot rule out a rare disobedience rate. Rerun if the wording changes.
