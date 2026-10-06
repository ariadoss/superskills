# Experiment A — basic-review finding calibration (Codex rubric import)

PREREG: `evals/reports/2026-10-05-review-calibration-PREREG.md` (committed
4d55446 before any comparative run). Intervention: "What earns a finding"
block in `skills/basic-review/SKILL.md` — introduced-in-diff rule, no
speculation, rigor-matching, prefer-no-findings. Adapted from Codex's
shipped review rubric (codex-rs/prompts/templates/review/rubric.md at
062439b).

Method note: the harness publishes grader pass/fail per run (its run-level
`score` uses an opaque formula), so the pre-registered "mean over the five
llm graders" is computed as per-grader pass-rate over 3 runs, then averaged
across the five graders. Identical arithmetic both arms.

## Results (3 runs/case/arm, with-plugin, same day 2026-10-06)

| Grader | Baseline | Change | Δ |
|---|---|---|---|
| review-calibration / flags-introduced-bug | 3/3 = 1.000 | 3/3 = 1.000 | +0.000 |
| review-calibration / skips-preexisting | 2/3 = 0.667 | 3/3 = 1.000 | +0.333 |
| review-calibration / skips-speculation | 2/3 = 0.667 | 3/3 = 1.000 | +0.333 |
| review-calibration / skips-style | 3/3 = 1.000 | 3/3 = 1.000 | +0.000 |
| review-clean / no-false-positive | 1/3 = 0.333 | 3/3 = 1.000 | +0.667 |
| **Primary (mean of five)** | **0.733** | **1.000** | **+0.267** |

skill-fired indicator: 3/3 in both arms (power gate held).

## Gates (pre-registered)

| Gate | Threshold | Observed | Verdict |
|---|---|---|---|
| Primary improvement | ≥ +0.15 | +0.267 | PASS |
| No grader regression | none ≥ 0.34 | worst +0.000 | PASS |
| no-false-positive not below baseline | — | 0.333 → 1.000 | PASS |
| Firing power | ≥ 2/3 both arms | 3/3 and 3/3 | PASS |

**Decision: ADOPTED.** The edit stays; `basic-review` version 1.1.0 → 1.2.0.

Mechanism evidence: the two baseline calibration failures were the model
presenting the pre-existing `parse_qty` off-by-one as a finding and
speculating about the retry loop; the change arm eliminated both while
introduced-bug detection stayed 3/3. The precision control moved 1/3 → 3/3:
on a benign diff the baseline model invented findings twice; with the
prefer-no-findings block it reported "nothing worth fixing" every time.

Cost: $3.23 total (price run $0.29; baseline clean $0.68; baseline
calibration $0.82; change $1.44) against the $19 budget.

Limits: n=3/case/arm; no same-run no-plugin arm (same-day model drift
between runs is an uncontrolled small confound, per the PREREG's stated
limit); the harness `--case` flag is a single glob, so the interrupted
first baseline attempt ran review-clean only — completed same day with a
second command, before the intervention was applied.
