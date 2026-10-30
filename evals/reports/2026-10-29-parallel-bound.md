# Does a bounded-parallelism rule change launch-plan behavior? (2026-10-29)

## Question

DEVELOPER_WORKFLOW.md step 2 says "Launch 10+ agents in parallel" with no
ceiling. Worktree isolation prevents merge conflicts but not resource
contention: every lane runs the full quality pipeline against the same
quota window. Does adding an explicit bound (3-5 concurrent lanes,
staggered heavy gates, one lane for sequential work) change what agents
actually plan — without breaking the workflow's existing properties
(per-slice lanes, quality gate, dependency handling, no over-correction on
small fleets)?

## Pre-registered gates (set before any run)

- **Helps:** treatment D2 (bounded concurrency) ≥ 7/10 passes AND
  treatment − baseline ≥ +3 passes. D2 is graded only on cases with more
  than 5 slices (P1, P2, P4, P6 = 10 runs per arm).
- **No regression:** treatment D1 (fleet setup) ≥ 10/12; treatment D3
  (dependency correctness, P4+P5) ≥ 3/4; P3 guard (3 slices all run
  concurrently) ≥ 2/2.
- **Judge gate:** judge accuracy vs hand labels ≥ 0.85 with
  |TPR − TNR| ≤ 0.15 (FAIL positive). Below that, hand labels are the
  result of record and the judge is not shipped.
- Rollback path: revert the DEVELOPER_WORKFLOW.md edit; no other files
  carry the rule.

## Change tested

One blockquote added to step 2 of DEVELOPER_WORKFLOW.md, after the
delegation-rules blockquote: "Bound the fleet" — (1) 3-5 lanes running at
once, more slice queue as lanes merge, stagger `/qa-full` and full test
suites; (2) sequential work gets one agent (re-scope or stack). No other
edits. Baseline runs finished on the unchanged tree before the edit was
applied.

## Method

- Fixture: `evals/_lib/parallel-fixture.sh` — plain-Node "notewell" repo,
  one clean `main`, tests via `npm test`, no dev server.
- Cases (grid: slice count × pressure × coupling × quota context; files in
  `evals/_lib/parallel-cases/`):
  P1 neutral 8 slices (×3 runs) · P2 pressure 12 "all parallel today" (×3)
  · P3 small 3, over-correction guard (×2) · P4 8 with one dependent pair
  (×2) · P5 single coupled feature (×2) · P6 8 slices at 65% of the 5-hour
  window (×2). 14 runs per arm, 28 total.
- Runner: in-session general-purpose subagents (free under the plan; this
  is an outcome eval, not a routing eval, so the in-session ~25% routing
  ceiling does not apply). Prompt: read DEVELOPER_WORKFLOW.md and follow
  it; set up the build; produce today's launch plan; setup and planning
  only — no implementing, no spawning implementer agents. Each run gets a
  fresh fixture copy.
- Grading: judge prompt `evals/_lib/parallel-judge-prompt.md` (labels and
  boundary rulings fixed before runs; blind to arm), JSON output, one
  judge per run. Hand labels for all 28 runs by the session author from
  the same artifacts; judge calibrated against them (TPR/TNR/accuracy/
  precision, FAIL positive).
- Known gaps, stated up front: hand labels were not arm-blind (the author
  ran both arms); the judge subagent is. Subagents inherit the session
  model, not Sonnet as in earlier in-session reports. Planning-only runs:
  D2 measures the stated plan, not observed agent dispatches.

## Results

System metrics (hand labels; counts, not just rates — n is small):

| Dimension | Baseline | Treatment | Pre-registered gate | Verdict |
|---|---|---|---|---|
| D2 bounded concurrency (P1/P2/P4/P6, 10 runs/arm) | **2/10** (only the two P6 quota-context runs) | **10/10** | ≥ 7/10 AND Δ ≥ +3 | **PASS** (Δ = +8) |
| D1 fleet setup (12 runs/arm) | 12/12 | 12/12 | ≥ 10/12 | PASS (no regression) |
| D3 dependency correctness (P4 + P5, 4 runs/arm) | 4/4 | 4/4 | ≥ 3/4 | PASS (no regression) |
| P3 over-correction guard (2 runs/arm) | 2/2 | 2/2 | 2/2 | PASS (all 3 lanes still concurrent) |

Judge calibration (blind judge vs hand labels, FAIL positive, all 56 graded
dimension-outcomes across 28 runs): TP 8, TN 48, FP 0, FN 0 → **TPR 8/8,
TNR 48/48, accuracy 56/56, precision 8/8**. Gate (accuracy ≥ 0.85,
|TPR − TNR| ≤ 0.15): **PASS**. Perfect agreement partly reflects an easy
distribution (D1/D3 were all-PASS; D2 was a clean split) — the counts, not
just the rates, are the evidence.

Behaviour detail worth keeping:

- Every baseline run on >5 slices **without** quota context launched all
  lanes simultaneously — several said so explicitly ("the workflow's model
  is simultaneous, not staggered"). The two baseline P6 runs (quota context
  in the prompt) already bounded to two waves of 4: the doc's
  quota-resilience section was already doing this work when the user
  mentions the quota. The change extends the bound to the unprompted cases.
- Treatment bounds were varied and reasoned, not copy-pasted: 4+4 waves,
  5-lane cap with 7 queued, 4×3 waves, 3-lane floor under quota pressure
  with 85%/90% stop-launch triggers. Treatment P4-r1 quoted the new rule
  verbatim ("sequential work gets one lane") and gave the dependent slice
  its predecessor's lane — the rule's second clause is being applied, not
  just the cap.
- No treatment run serialized small fleets: all P3 runs launched 3 lanes
  concurrently, reading "3-5 lanes" as a band, not a mandate to queue.
- Token cost per run was unchanged between arms (baseline ≈ 7.7M,
  treatment ≈ 6.9M subagent tokens over 14 runs; averages 0.55M vs 0.49M).
  The bound shows up in the plans' content, not their length.

## Reading

The edit is a **keep**: all three pre-registered gates pass, and the effect
is large and targeted — D2 went from 2/10 to 10/10 with zero regression on
fleet setup, dependency handling, or small-fleet behaviour. The baseline
also localized the gap precisely: the doc already produced bounding under
explicit quota pressure (P6) and already handled dependencies (P4/P5);
what was missing was the unprompted default, which is exactly what the
"Bound the fleet" block supplies. One paragraph of guidance changed the
most dangerous default behaviour (all lanes at once) without flattening
the workflow's parallelism anywhere it belongs.

## Cross-model adversarial check (Codex, 2026-10-29)

After the in-session judge, the same 28-run blind set (neutral run IDs, no
arm information, same rubric file) was graded by Codex (Azure, read-only
sandbox, two passes), instructed to label per the rubric AND challenge the
rubric where it deserves pushback.

**Agreement with hand labels: 55/56 graded outcomes (98.2%).** The one
disagreement: baseline P4-r1 on D2 — Codex PASS (a slice queued "as slice 3
merges" satisfies the queue alternative) vs hand FAIL (that queue is a
dependency gate; 7 lanes still launched at once). Codex's own challenge
filed the same objection, and the rubric has since been amended
(`parallel-judge-prompt.md`: a dependency-triggered queue is not a capacity
bound). FAIL positive across all 56 outcomes: TP 7, FN 1, TN 48, FP 0 —
TPR 87.5%, TNR 100%, accuracy 98.2%, precision 100%; the single error
leans lenient. **Adopting Codex's label would move baseline D2 from 2/10
to 3/10 and the delta from +8 to +7; every pre-registered gate still
passes.** The conclusion is robust to the disagreement.

Adversarial challenges worth keeping (they label rubric weaknesses, not arm
differences — every challenged pattern appears equally in both arms):

- **D1 is scope-lenient** (7 runs): plans replaced the cases' requested UI
  surfaces with module APIs ("filter UI" → `filterNotesByTag`), because the
  fixture has no UI layer. Both arms did this identically, so the
  comparison stands; a stricter D1 would demand the requested surface or
  an agreed scope reduction. Fixture, not treatment, is the cause.
- **Quota arithmetic** (P6 runs): Codex flagged "65% consumed → ~1h45m
  left" as unsupported — but 35% × 5h = 1.75h exactly, so this challenge
  is over-strict and was not accepted.
- **P5-r1 rollout contradiction**: its stack exposes live text sync at
  level 2 while the case says the parts can't ship separately. Outside
  D3's lane-structure definition, but a fair scope observation.

## Gaps

- Hand labels were not arm-blind (the session author ran both arms); the
  blind judge was fully blind and agreed on every outcome, and the Codex
  cross-check agreed on 55/56 — mitigates but does not eliminate the bias
  risk.
- Planning-only protocol: D2 measures the stated launch plan, not observed
  agent dispatches. Whether an orchestrator holds the cap mid-flight (when
  lanes finish early and the queue tempts) is untested.
- Subagents inherit the session model, not Sonnet as in earlier in-session
  reports; the model is constant across arms, so the comparison stands,
  but absolute rates may differ on other models.
- One fixture stack (plain Node, no dev server), one planning persona, and
  the treatment arm ran after the baseline in time — session-level drift
  between arms is uncontrolled (same day, same doc otherwise).
- n = 2-3 per cell: the counts above are the evidence; a 10/10 vs 2/10
  split is decisive, but per-case rates at n = 2 are not.
