# PREREG — orchestration-shape checklist in /write-plan (2026-10-04)

Registered before any run of the `writeplan-*` cases. Provenance: the pattern
taxonomy (pipeline, map-reduce, agent loop, judge loop, router, vote/debate,
plus boundary discipline: structured output, retry-with-fallback, human gates,
simplest-shape-wins) is adapted from PocketFlow's design docs; this run tests
whether inlining it as a naming checklist in `/write-plan` measurably improves
plans, in any harness the plugin installs into (the edit is markdown in the
skill body, host-agnostic by construction).

## Intervention (applied only between the two runs)

1. `skills/write-plan/SKILL.md`: new section "Orchestration shape (when the
   feature drives an LLM or agent)" after "Security & threat model" — the
   shape list, the simplest-shape rule, the boundary disciplines, and a
   silent-skip clause for features with no LLM component.
2. `ENGINEERING_STANDARDS.md`: canonical short section after YAGNI (inert for
   behaviour: no skill fetches this file; it is the contributor-canonical copy).

## Cases (all new, all run in both configurations)

| Case | Measures |
|---|---|
| `writeplan-batch-classify` | pipeline + map-reduce shape, structured output, retry/fallback, no fake agent |
| `writeplan-docs-agent` | agent loop chosen when steps are un-enumerable; bounds, scope, human gate |
| `writeplan-judge-loop` | separate verify step vs policy, bounded repair, escalation, human send gate |
| `writeplan-router-intake` | classify-then-dispatch, structured labels, low-confidence fallback |
| `writeplan-simple-crud` | **negative control**: no LLM feature must acquire AI machinery |
| `writeplan-overreach` | **discipline control**: 5-person "AI helper" stays RAG + one draft step, no multi-agent platform |

## Fairness rule (fixed in advance)

Graders grade **design structure, never vocabulary**: no grader requires the
reply to use the words "pipeline"/"agent loop"/etc. The change arm cannot win
by naming patterns; it wins only if the underlying design decisions improve.
The skill-fired graders are `tool_used` indicators (not scored), so Δ comes
only from the structural llm graders, which a plugin-less Claude can pass.

## Endpoints and thresholds (set before the runs)

**Amendment after calibration, before any comparative run.** Two single-case
debug runs measured $1.00–$1.53 per planning run (plans are long outputs),
which puts the original two-arm × 3-run design at ~$70–110 across both
configurations. The question under test is whether the checklist improves
**write-plan's own output**, so the right comparison is the with-plugin arm
across the two tree states; the no-plugin arm answers a different question
(at 2× the cost). Revised design, registered before any comparative data
existed:

- Runs: `--ablation none` (with-plugin arm only), 3 runs/case
  (harness default), both configurations identical except the intervention.
- **Primary:** mean score over the four positive cases, change-run vs
  baseline-run (with-arm in both).
- **Adopt** the edit if: primary improves by ≥ +0.10 AND no positive case
  regresses by ≥ 0.34 (one run's worth) AND both controls do not fall below
  their baseline-run values.
- **Reject** otherwise: revert the write-plan edit, keep the cases and report
  the negative result. A null is a real answer, not a failed run.
- Stated limit: no same-run no-plugin arm, so slow same-day model drift
  between the two runs is an uncontrolled (small) confound.
- Counts reported alongside rates at this sample size, per RUBRIC.md.

One grader was calibrated on the debug runs before the baseline: the router
case's condition 3 originally required a low-confidence mechanism; the debug
reply met the property (undecidable → human via the refusal path) without the
mechanism, and the judge correctly failed the stricter wording. Fixed to grade
the property (any named path that surfaces uncertain classifications to a
human), not the mechanism.

**Second calibration pass, after baseline run 1 (04:50, $10.74, superseded).**
Open coding found three instrument bugs, all fixed before any comparative use
of the numbers: (a) 4 of 18 runs timed out at 300s mid-plan — the graders
were judging truncated replies — so `timeout_seconds` is now 600 on all six
cases; (b) the agent-loop grader's condition 1 read as excluding the
plain-code-around-a-loop hybrid the boundary ruling meant to allow (the
observed hybrid — "plain code decides whether to run, the agent decides what
to do" — is the preferred design); (c) the overreach grader demanded RAG as
the mechanism, failing replies that chose a smaller shape (whole handbook
in-context with caching; a zero-code shared workspace) — condition 1 now
grades minimalism by any mechanism. Baseline run 1 is retained in
`evals/results/` but its scores are invalid as an instrument (truncation) and
its graders are superseded; the 600s re-run is the registered baseline.
Product finding carried into the report either way: write-plan fired 3/3 on
infrastructure-flavoured asks and 0/3 on greenfield/product asks
(docs-agent, overreach, simple-crud) — a routing gap independent of this
intervention.

## Judge calibration plan

Human-label every llm-graded run (both arms, both configurations) against the
grader's own PASS/FAIL definition; report TPR, TNR, accuracy, precision with
FAIL as the positive class and the TP/TN/FP/FN counts. A TPR–TNR gap over 25
points gets named (harsh vs lenient) and the disagreeing runs quoted.

## Cost

Measured in calibration: $1.00–$1.53 per planning run, ~$0.02/run in judge
votes. Revised design: two configurations × 6 cases × 3 runs (no ablation
arm) ≈ 36 runs, expected **$36–55 total**, `--max-cost-usd 40` per
configuration as the abort ceiling. (Original estimate, $12–18 for the
two-arm design, was written before any run and superseded by the measured
per-run cost.)
