# Experiment B — plan-example phrasing in /write-plan (contrastive vs positive-only)

PREREG: `evals/reports/2026-10-06-writeplan-examples-PREREG.md` (committed
68c3bca before any run). Arms: B = no examples; P = three high-quality task
lists; C = P plus three low-quality ("filler to avoid") lists. Case:
`writeplan-plan-quality` (webhook-reconciliation domain, disjoint from all
example domains — anti-leakage); guards: `writeplan-simple-crud`,
`writeplan-judge-loop`. 3 runs/case/arm, with-plugin, same day 2026-10-06.
Skill fired 3/3 in every arm (power gate held throughout).

## Results

| Grader | B | P | C |
|---|---|---|---|
| plan-quality / steps-verifiable | 2/3 = 0.667 | 1/3 = 0.333 | 3/3 = 1.000 |
| plan-quality / no-filler | 3/3 = 1.000 | 3/3 = 1.000 | 3/3 = 1.000 |
| plan-quality / decomposition-covers | 3/3 = 1.000 | 2/3 = 0.667 | 3/3 = 1.000 |
| **Primary (mean of three)** | **0.889** | **0.667** | **1.000** |
| guard: simple-crud / no-ai-machinery | 1.000 | 1.000 | 1.000 |
| guard: judge-loop / shape-judge-loop | 0.667 | 0.667 | 0.333 |

**Direct contrast endpoint Δ(C − P) = +0.333.** The prereg's concern was
that negative examples might hurt (Δ ≤ −0.10 would have recorded "negative
examples measurably hurt"). The data says the opposite at this power:
positive-only examples hurt (P − B = −0.222), and adding the bad examples
*after* the good ones produced the best arm. The likely mechanism, visible
in the failing P runs: with only good examples, plans drifted toward the
examples' surface shape and lost verifiable steps; the filler block appears
to sharpen the contrast so the good pattern is applied rather than mimicked.

## Gate arithmetic and an honest caveat

| Gate (prereg) | P | C |
|---|---|---|
| beats B by ≥ +0.10 | −0.222 ✗ | +0.111 ✓ |
| steps-verifiable improves ≥ +0.10 | −0.333 ✗ | +0.333 ✓ |
| no-filler improves ≥ +0.10 | +0.000 ✗ | +0.000 ✗ (ceiling: 1.000 in every arm — unsatisfiable) |
| no guard regresses ≥ 0.34 | 0.000 ✓ | −0.333 (one run-flip; inside the prereg's own noise threshold of 0.34) ✓ |

**Drafting defect, disclosed:** the no-filler sub-gate is mathematically
unsatisfiable whenever a grader sits at ceiling in the baseline — no arm
could ever have passed it. The gate's intent (gains must not be confined to
filler-avoidance; no real regression elsewhere) is satisfied by C: the
entire primary gain is steps-verifiable +0.333, no primary-case grader
regressed, and the guard wobble is exactly the single-flip noise the
prereg's 0.34 threshold was set to tolerate.

**Decision: ADOPT C** (the contrastive block stays in
`skills/write-plan/SKILL.md`), under the intent-of-the-gate reading plus
the maintainer's standing instruction of 2026-10-06 ("keep what improves").
The strict letter of the prereg would have said "adopt neither"; a reader
who weights the letter over the intent should treat this adoption as
provisional and re-run at n=5 before relying on it.

Limits: n=3/arm — single run-flips move any grader by 0.333, so P's
degradation and C's judge-loop guard wobble are each within noise; the
C-vs-B margin (+0.111) rests on roughly two flipped runs. Same-day
sequential arms carry uncontrolled drift. The three-arm cost was $26.40
(B $9.71, P $8.66, C $8.03) against the $45 budget.
