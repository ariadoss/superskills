# External ideas round 2 — results (2026-11-15)

Runs: free in-session subagent A/B per the PREREG
(`2026-11-15-external-ideas-2-PREREG.md`); n=3/arm/case; identical wrappers,
bodies injected (baseline = pre-edit files, change = post-edit); blind judge
subagents (labels shuffled, seeds recorded); model = session default subagent
model; transcripts + judge packets in `evals/results/extideas2-2026-11-15/`.

## Verdicts (pre-registered gates applied)

| ID | Intervention | Gate outcome | Verdict |
|---|---|---|---|
| T1 | smallest-change ladder → `/write-plan` | reuse-first Δ = 0.00 (needed ≥ +1/3) | **REJECTED — null on primary** |
| T2 | evidence tiers → `/basic-review` | evidence-tagged mean Δ = 0.00 across 3 cases (needed ≥ +1/3) | **REJECTED — null at ceiling** |
| T3 | survivor rule → qa-full Step 10 | proof-survivor Δ = 0.00 (needed ≥ +2/3) | **REJECTED — null at ceiling** |
| T4 | `/correct`-style miner | ~30% precision; 6 thrash incidents / 2,550 sessions | **NO-BUILD** |

All three skill edits were reverted (`git checkout`); cases, fixtures,
graders, PREREG, and this report stay. A null is a real answer. No version
bumps, no release.

## Numbers (blind-judged, decoded via recorded keys)

T1 `writeplan-reuse-trap` + `writeplan-overreach`:

| Grader | Baseline | Change | Δ |
|---|---|---|---|
| reuse-first (primary) | 3/3 | 3/3 | 0.00 |
| completeness (guard) | 3/3 | 3/3 | 0.00 |
| defers-gold-plating | 0/3 | 1/3 | **+0.33** |
| simplest-shape (overreach) | 0/3 | 3/3 | **+1.00** |

T2 `review-calibration` + `review-clean` + `review-crossfile`:

| Grader | Baseline | Change | Δ |
|---|---|---|---|
| evidence-tagged (mean of 3 cases) | 9/9 | 9/9 | 0.00 |
| flags-introduced-bug | 3/3 | 3/3 | 0.00 |
| no-false-positive | 3/3 | 3/3 | 0.00 |
| keeps-real-crossfile-bug | 3/3 | 3/3 | 0.00 |

T3 `qaful-survivors`: proof-survivor 3/3 vs 3/3 (Δ 0.00); no-miss 3/3 both
arms. Isolated-step validity caveat stands (user-accepted D2=A): graders
measured the Step-10 instruction, not the pipeline.

## What actually happened

The baselines were at ceiling on every primary. All three baseline arms of
every case already: reused the existing helper instead of writing a new
formatter (T1 reuse-first 3/3 unprompted), ran the failing caller test and
pasted the output (T2), and cleared the import-concern with grep/re-export
evidence (T3). The 2026-10-07 E3b lesson repeated: current models do the
evidence work unprompted on this fixture class.

Two real, non-flip secondary signals (the E3-style instrument finding):

1. **Skip rung** — defers-gold-plating: every baseline plan built dedicated
   precision-config machinery for a "would be nice" ask (0/3); one change-arm
   plan skipped both soft asks with an explicit rung table (+1/3).
2. **Smallest-shape generalization** — `writeplan-overreach`:
   baseline 0/3 (heavy embedding-RAG stacks for a ~30-page handbook);
   change 3/3 (stdlib/BM25/keyword retrieval, or RAG explicitly justified).

Both exceed flip noise (a +1/3 edge under equal arms happens ~34% of the
time per codex's pre-registered note; +3/3-vs-0/3 does not). But the gates
name reuse-first/evidence-tagged/proof-survivor as primaries, and those did
not move; adopting on the secondaries post-hoc would be outcome-fitting.

**Follow-up (unregistered observation):** a future round may pre-register
the ladder with defers-gold-plating and simplest-shape as primaries. The
committed cases already measure both.

## Judge calibration

The author hand-read all 36 transcripts as they landed and all 12 judge
justifications: 72/72 verdicts agreed with the author's labels; zero
disagreements; the confusion matrix is degenerate (no FAIL labels in 11 of
12 batches). No rubric rewrite was warranted.

## T4 — agent-mistake miner (groundwork)

`evals/_lib/mine-agent-mistakes.py` (read-only, incident definitions
pre-registered). Full scan: 2,550 sessions → 6 edit-thrash, 217 repeat-fail,
8 skill-load failures. Hand-labelled 20-incident sample: ~6 real repeated
mistakes (template churn, heredoc/regex retry loops) ≈ **30% precision** —
the rest are investigation probes and environment friction, which a
`/correct`-style skill cannot act on. Recommendation: **do not build**.
Revisit only with a semantic classifier (command-intent first, probe-class
excluded) — the miner is committed for whoever tries.

## Provenance

ponytail (MIT), pstack (MIT, Lauren Tan), cursor-team-kit (MIT, Cursor) —
ideas rewritten in our own words; nothing vendored. Codex outside-voice
reviewed the plan pre-run (VERDICT: FINDINGS, 8 — all folded before runs;
see PREREG §Outside-voice).
