# PREREG — qa-full cross-check synthesis rules (qaful-synthesis)

Registered before any run of `qaful-synthesis`. Provenance: cursor/plugins
`thermos` orchestrator (fetched 2026-10-07). Overlap note: the 2026-10-05
plan rejected a qa-full *accounting* experiment because the ledger already
exists — this measures the *synthesis* rule the ledger lacks (verified:
`skills/qa-full/SKILL.md` Step 3 has no merge/dedup instruction between the
two passes). Like the adopted basic-review and clean-code experiments (and
unlike the new-skill A/Bs), this is a skill-body edit to an already-installed
skill: qa-full fires in both arms, so there is no skill-present ordering
contamination. Host-agnostic by construction (markdown skill-body edit).

## Intervention (applied only between the two runs)

`skills/qa-full/SKILL.md` gains the "Cross-check against the correctness
pass" block (full text in the plan) at the end of Step 3 — after the
`/clean-code` paragraph, before the `/code-review ultra` paragraph. It
reconciles `/clean-code`'s report against `/review`'s applied fixes: the two
passes' fix rounds are sequential (`/review` runs and its fixes are committed
before `/clean-code` starts), so the finding lists never coexist — the rule
has the second pass reconcile its findings against the first's already-applied
fixes at its report time, before its own fix round.

## Cases

| Case | Role |
|---|---|
| `qaful-synthesis` (new) | primary: synthesis-present + verdict-discipline |

## Fairness rule (fixed in advance)

Graders grade behaviour (whether the two faces of the planted root cause are
connected, merged, or cross-cited in the report/ledger, and whether the
verdict follows the SHIP-READY contract), never vocabulary. skill-fired
graders are unscored indicators. Boundary rulings are in the grader texts,
committed before runs.

## Endpoints and thresholds (set before the runs)

- Price calibration: one `--runs 1` run of `qaful-synthesis`
  (`--max-cost-usd 8`). ABORT (keep the case, record the price in the
  consolidated report, skip the experiment) if it exceeds $6.50 — qa-full's
  fan-out cost is unmeasured; this cap is the experiment's kill switch.
  Mechanism: the harness checks `--max-cost-usd` before each run and aborts
  with exit 2 plus partial results; a cap-tripped run's scores read 0 for
  unexecuted graders — check `cases[].arms.*[].error` before reading any Δ.
- Runs: `--ablation none`, 3 runs/case/arm, both arms same day.
  Baseline: `claude plugin eval . --case qaful-synthesis --runs 3 --ablation
  none --trust-plugin --no-publish --scaffold --allow-tools Bash
  --judge-model sonnet --max-cost-usd 20 --json
  evals/results/qaful-baseline.json`; change: same command with
  `evals/results/qaful-change.json`. Budget: baseline `--max-cost-usd 20`,
  change `--max-cost-usd 20` (≤ $48 total with the price run).
- **Firing-power gate:** qa-full fires in ≥ 2/3 runs in BOTH arms on the
  primary case. Below that: under-powered, adopt nothing.
- **Primary:** mean of synthesis-present + verdict-discipline over 3 runs,
  change vs baseline.
- **Adopt** if: primary ≥ +0.15 AND synthesis-present alone ≥ +0.15 AND
  verdict-discipline does not regress at all AND the firing gate holds.
- **Reject** otherwise: revert the skill edit, keep case + PREREG, report
  the null. A null is a real answer.
- Stated limits: n=3; same-day drift between the two sequential runs is an
  uncontrolled small confound (precedent: 2026-10-06 calibration report);
  `/review` may be unavailable in-sandbox, in which case `/basic-review`
  runs — graders are written to accept either path.
