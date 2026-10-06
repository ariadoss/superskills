# PREREG — basic-review finding-calibration (Codex rubric import)

Registered before any run of the `review-*` cases. Provenance: the
finding-worthiness conditions and "prefer no findings" stance are adapted
from Codex's shipped review rubric (codex-rs/prompts/templates/review/
rubric.md at 062439b); this run tests whether inlining a distilled version
into /basic-review measurably improves review precision and calibration in
any harness the plugin installs into (the edit is markdown in the skill
body, host-agnostic by construction).

## Intervention (applied only between the two runs)

`skills/basic-review/SKILL.md`: new block "What earns a finding" after the
"Be calibrated" guidance in ## Review (full text in the plan), plus the
closing precision line folded into the existing Report section guidance.

## Cases (both run in both configurations)

| Case | Measures |
|---|---|
| `review-calibration` | flags the introduced bug; skips pre-existing, speculation, style |
| `review-clean` | precision control: no invented findings on a benign diff |

## Fairness rule (fixed in advance)

Graders grade behaviour visible in the reply (what was flagged, how it was
framed), never vocabulary. `skill-fired` graders are unscored indicators.
The change arm cannot win by naming the rules; only by which findings appear.

## Endpoints and thresholds (set before the runs)

- Cost calibration first: one `--runs 1` run of `review-calibration`
  (`--max-cost-usd 3`). ABORT the experiment (keep cases, report the price)
  if that single run exceeds $2.50.
- Runs: `--ablation none` (with-plugin arm only), 3 runs/case, both
  configurations identical except the intervention. Budget: baseline
  `--max-cost-usd 8` + change `--max-cost-usd 8` (≤ $19 total with the
  calibration run).
- **Firing-power gate:** the `skill-fired` indicator must show basic-review
  fired in ≥ 2/3 runs in BOTH arms. Below that the experiment is
  under-powered (a single firing flip moves a case mean by 0.33): report
  under-powered, do not adopt. Precedent: the 2026-10-04 report's own power
  analysis ("a single firing flip moves the primary mean by 0.083").
- **Primary:** mean over the five llm graders (4 in calibration + 1 in
  clean), change-run vs baseline-run.
- **Adopt** the edit if: primary improves ≥ +0.15 AND no single grader
  regresses ≥ 0.34 AND `no-false-positive` alone does not regress AND the
  firing-power gate holds.
- **Reject** otherwise: revert the skill edit, keep the cases, report the
  null. A null is a real answer.
- Stated limit: no same-run no-plugin arm; same-day model drift between the
  two runs is an uncontrolled (small) confound — precedent: the 2026-10-04
  amendment.
