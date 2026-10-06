# Experiment E — Codex testing philosophy in /write-plan (structural close-out)

PREREG: `evals/reports/2026-10-06-writeplan-testphilosophy-PREREG.md`
(committed before any run, with two registered amendments, both before any
comparptive data existed). Intervention (never applied): verification
ordered specific→broad; no test frameworks into test-less repos; repair
loops bounded (3 attempts, then report).

## Result: CLOSED UNMEASURED — firing-power gate failed at every phrasing

| Phrasing | skill-fired | specific-first | no-framework |
|---|---|---|---|
| "my dotfiles repo… backup.sh" (original) | 0/3 | 0/3* | 3/3* |
| "our ops repo… pile of shell scripts" (amend 1) | 0/3* | 0/3* | 3/3* |
| "~40 hosts, cron, on-call" (amend 2, fleet weight) | **1/3** | 1/3 | 3/3 |
| (*plugin-less runs — the skill never fired) | | | |

The preregistered firing gate (≥ 2/3) failed at all three weights, so no
comparative arm ran and the skill edit was never applied. Cost across the
three calibrations: $2.97 (plus $0.17 discarded when the eval account hit
its session limit mid-run, and one $2.46 guard run).

## The finding (dose-response, consistent with 2026-10-04)

Write-plan's firing climbs with ask WEIGHT, not domain: 0/3 personal →
0/3 team-utility → 1/3 fleet-scale → (contrast, same day) 3/3 on a
system-scale urgent ask ("worker queue backs up… reconciliation job").
The 2026-10-04 report measured the same shape (0/3 docs-agent, 0/3
overreach, 1/3 simple-crud vs 3/3 batch/router) and called it "a
skill-design question" — this run extends it to write-plan with a
controlled gradient. Under-triggering on utility-style "plan this for me"
asks is now the single biggest measured gap in write-plan's description.

Subsidiary observation: even plugin-less, `no-framework-imposed` scored
3/3 at every weight (the model honors an explicit user constraint without
help), while `specific-first` never exceeded 1/3 — the testing-philosophy
guidance has real headroom the day the trigger fires.

## Disposition

- Case + graders kept as a permanent **firing-gap probe** (the suite's
  first case whose primary discriminators are verification-strategy
  shape).
- The intervention text is preserved verbatim in the PREREG for the day a
  description fix makes the case fire ≥ 2/3; rerun then is a two-command
  A/B.
- Follow-up (not run today; description-wording precision is a closed
  question per evals/README.md, but TPR-side under-firing is explicitly
  open): restructure write-plan's description toward utility-scale asks,
  gated on firing ≥ 2/3 here WITHOUT losing the offtopic negative
  controls.
