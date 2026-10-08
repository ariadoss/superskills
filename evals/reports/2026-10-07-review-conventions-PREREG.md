# PREREG — basic-review repo-pinned conventions discovery

Registered before any run of `review-conventions`. Provenance: vercel-labs
open-agents `.agents/skills/code-review/SKILL.md` (fetched 2026-10-07) checks
CONVENTIONS.md/AGENTS.md/.editorconfig before reviewing. Distinct from the
adopted 2026-10-06 "What earns a finding" block: that block decides which
candidates become findings; this adds a discovery step whose hits are repo-
pinned. Host-agnostic by construction (markdown skill-body edit).

## Intervention (applied only between the two runs)

`skills/basic-review/SKILL.md` gains one subsection after the "What earns a
finding" block (full text in the plan): repo-pinned conventions discovery,
with `(convention: <file>)` citation. Two declared UNMEASURED riders in the
same edit: PR-URL input routing (Scope bullet) and the trigger-conditions
sentence (Report section). Riders are guarded only by the regression cases;
they never fire in any fixture (no PR URLs, no severity-ambiguous findings).

## Cases

| Case | Role |
|---|---|
| `review-conventions` (new) | primary: cites-convention + no-convention-bleed |
| `review-clean` (unchanged) | regression guard: no invented findings on a benign diff |
| `review-calibration` (unchanged) | regression guard: flags introduced bug, skips pre-existing/speculation/style |

## Fairness rule (fixed in advance)

Graders grade behaviour (what was flagged, whether the pinned rule was
connected to the finding), never vocabulary. skill-fired graders are unscored
indicators. Boundary rulings are in the grader texts, committed before runs.

## Endpoints and thresholds (set before the runs)

- Price calibration: one `--runs 1` run of `review-conventions`
  (`--max-cost-usd 3`). ABORT (keep cases, report the price) if it exceeds
  $2.50.
- Runs: `--ablation none`, 3 runs/case/arm, both arms same day.
  Budget: baseline `--max-cost-usd 8`, change `--max-cost-usd 8`
  (≤ $19 total with the price run).
- **Firing-power gate:** basic-review fires in ≥ 2/3 runs in BOTH arms on the
  primary case. Below that: under-powered, adopt nothing.
- **Primary:** mean of cites-convention + no-convention-bleed over 3 runs,
  change vs baseline.
- **Adopt** if: primary ≥ +0.15 AND no grader across all three cases
  regresses ≥ 0.34 AND `review-clean`/`no-false-positive` does not regress at
  all AND the firing gate holds.
- **Reject** otherwise: revert the skill edit, keep cases + PREREG, report
  the null. A null is a real answer.
- Stated limit: n=3; same-day drift between the two sequential runs is an
  uncontrolled small confound (precedent: 2026-10-06 calibration report).
