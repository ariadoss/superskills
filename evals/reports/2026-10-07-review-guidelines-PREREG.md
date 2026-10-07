# PREREG — basic-review repository review guidelines (REVIEW_GUIDELINES.yaml)

Registered before any run of `review-guidelines`. Provenance: auggie
`plugin_marketplace/code-review/commands/local.md` Step 2 (fetched
2026-10-07) reads repo-pinned review rules before reviewing; the schema and
citation were adapted to a tool-neutral root file (REVIEW_GUIDELINES.yaml,
glob-scoped areas, `(Guideline: <area-id>)` citation). Distinct from the
adopted 2026-10-06 "What earns a finding" block: that block decides which
candidates become findings; this adds an opt-in contract the repo itself
pins, which can only add findings or name the house fix for a default one.
Host-agnostic by construction (markdown skill-body edit).

Dependency note: this experiment runs after Task 1's decision, and this
PREREG records it so the baseline state is unambiguous. Task 1 (conventions
discovery) was REJECTED — its skill edit was reverted, so
`skills/basic-review/SKILL.md` stands at its clean v1.2.0 state ("What earns
a finding" is the last subsection of ## Review; there is no Task-1
subsection). The baseline below is that clean tree.

## Intervention (applied only between the two runs)

`skills/basic-review/SKILL.md` gains one subsection directly after the "What
earns a finding" block (full text in the plan): "Repository review guidelines
(opt-in contract)" — load `REVIEW_GUIDELINES.yaml` from the repo root when
present, match each changed path against every area's `globs`, cite
guideline-sourced findings `(Guideline: <area-id>)`, and never treat a
missing, unreadable, or invalid-YAML file as a finding. Declared UNMEASURED
limits: the invalid-YAML fallback and glob-scoping edge cases are defensive
text guarded only by the regression cases — no fixture exercises them. If E2
adopts, a follow-up case may pin them.

## Cases

| Case | Role |
|---|---|
| `review-guidelines` (new) | primary: cites-guideline + no-bleed |
| `review-guidelines-clean` (new) | precision control: no-guideline-findings on a guideline-conforming diff |
| `review-clean` (unchanged) | regression guard: no invented findings on a benign diff |
| `review-calibration` (unchanged) | regression guard: flags introduced bug, skips pre-existing/speculation/style |

## Fairness rule (fixed in advance)

Graders grade behaviour (what was flagged, whether the pinned rule was
connected to the finding), never vocabulary. skill-fired graders are unscored
indicators. Boundary rulings are in the grader texts, committed before runs.

## Endpoints and thresholds (set before the runs)

- Price calibration: one `--runs 1` run of `review-guidelines`
  (`--max-cost-usd 3`). ABORT (keep cases, report the price) if it exceeds
  $2.50.
- Runs: `--ablation none`, 3 runs/case/arm, both arms same day. The
  harness's `--case` takes ONE glob: baseline and change both use
  `--case 'review-*'`, which matches exactly the five review cases existing
  at baseline time (review-guidelines, review-guidelines-clean,
  review-conventions, review-clean, review-calibration — 15 runs per arm).
  Budget: baseline `--max-cost-usd 8`, change `--max-cost-usd 8`
  (≤ $19 total with the price run).
- **Firing-power gate:** basic-review fires in ≥ 2/3 runs in BOTH arms on the
  primary case. Below that: under-powered, adopt nothing.
- **Primary:** mean of cites-guideline + no-bleed + no-guideline-findings
  over 3 runs, change vs baseline.
- **Adopt** if: primary ≥ +0.15 AND no grader across all four cases
  regresses ≥ 0.34 AND `review-clean`/`no-false-positive` and
  `review-guidelines-clean`/`no-guideline-findings` each do not regress at
  all AND the firing gate holds.
- **Reject** otherwise: revert the skill edit, keep cases + PREREG, report
  the null. A null is a real answer.
- Stated limit: n=3; same-day drift between the two sequential runs is an
  uncontrolled small confound (precedent: 2026-10-06 calibration report).
