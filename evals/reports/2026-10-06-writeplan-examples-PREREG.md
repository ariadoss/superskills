# PREREG — plan-example phrasing in /write-plan (contrastive vs positive-only)

Registered 2026-10-06, before any run of the arms below. Provenance: Codex
ships high/low-quality plan example pairs in both of its current system
prompts (base_instructions/default.md:101-119, gpt_5_2_prompt.md:87-107 at
062439b) with no public ablation; the maintainer's prior is that negative
examples can hurt. This run decides which phrasing, if either, measurably
improves our plans. Host-agnostic by construction (markdown skill-body edit).

## Arms (three tree states, with-plugin, same day)

- **B** — current tree (no examples section in skills/write-plan/SKILL.md).
- **P** — skills/write-plan/SKILL.md gains "Plan Quality Examples" (three
  high-quality task lists; domains: CSV export, duration parsing, token
  auth).
- **C** — P plus a "Filler to avoid" block (three low-quality lists).

## Cases

| Case | Role |
|---|---|
| `writeplan-plan-quality` (new) | primary: step verifiability, no filler, decomposition |
| `writeplan-simple-crud` | regression guard (negative control must stay negative) |
| `writeplan-judge-loop` | regression guard (orchestration shape must not regress) |

## Fairness rule (fixed in advance)

The case domain (webhook reconciliation) deliberately matches NO example
domain (CSV export, duration parsing, token auth) — anti-leakage per
evals/METHODOLOGY.md ("Never reuse evaluation cases as few-shot examples in
the thing being graded"). Graders grade task-list structure (verifiability,
filler, decomposition), never vocabulary — no grader may require or reward
words lifted from the skill text. skill-fired graders are unscored
indicators.

## Endpoints and thresholds (set before the runs)

- Planning runs measured $1.00–1.53 on 2026-10-04; 3 cases × 3 arms × 3 runs
  = 27 runs. Each per-case command carries `--max-cost-usd 7`; abort the
  experiment if any single command reports cost > $7.00 or if arm B's total
  implies > $60 for the experiment.
- `--case` is a single name glob (verified 2026-10-06: a second --case
  overrode the first in the review baseline), so each arm runs three
  per-case commands.
- **Firing-power gate:** write-plan must fire in ≥ 2/3 runs per arm on
  writeplan-plan-quality (the prompt is infrastructure-flavoured to protect
  this; 2026-10-04 measured write-plan 3/3 on infrastructure-flavoured
  prompts, 0/3 on greenfield product asks). Below that, report
  under-powered and adopt nothing.
- **Primary:** mean of the three llm graders on `writeplan-plan-quality`,
  per arm (harness per-run grader scores, averaged over runs, then over
  graders).
- **Adopt P or C** (whichever is higher) if it beats B by ≥ +0.10 AND
  `steps-verifiable` and `no-filler` each individually improve (≥ +0.10)
  AND neither guard case regresses ≥ 0.34 vs B.
- **Direct contrast endpoint (the maintainer's actual question):** report
  Δ(C − P) on the primary. If Δ(C − P) ≤ −0.10, record "negative examples
  measurably hurt" — a positive finding validating the prior, not a failed
  run. If |Δ(C − P)| < 0.10, phrasing is indistinguishable at this power.
- On an adoption tie between P and C (within 0.05): adopt P (simpler,
  matches the prior).
- **Adopt neither** if no arm clears the B-comparison gate — report the
  null as the answer.
- Stated limit: same-day drift across three sequential arms is an
  uncontrolled (small) confound.
