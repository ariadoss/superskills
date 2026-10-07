# Experiment C2 — compaction/handoff framing for quota-resilience (measured null)

PREREG: `evals/reports/2026-10-06-quota-handoff-PREREG.md` (committed
8dfa122 before any run). Provocation: the maintainer's "nothing from
compaction framing was useful?" — the original rejection rested on section
equivalence; this run was to measure the framing delta.

## Result: REJECTED — no headroom (baseline at ceiling), skill untouched

| Grader | Baseline (n=3) |
|---|---|
| quota-stop-handoff / handoff-selfcontained | 3/3 = 1.000 |
| quota-stop-handoff / handoff-antiredo | 3/3 = 1.000 |
| quota-stop-handoff / skill-fired (indicator) | 3/3 |
| quota-stop guard / honest-state, mentions-note, salvage-commit | all 3/3 = 1.000 |

The preregistered adopt gate (primary Δ ≥ +0.175) is unreachable from a
1.000 baseline, so the change arm was not run (spending ~$1.70 to confirm
a floor violates the no-headroom rule the 2026-10-04 report established).
**The original rejection's ground is now measured, not asserted: the
existing Goal/Done/In-flight/Next-steps/Verify/Context/Hops spec already
produces self-contained, anti-redo, constraint-carrying notes.** The Codex
framing sentence would be redundant prose.

Calibration disclosure (added by qa-full review): the three baseline PASSes
were desk-verified as true positives against the grader evidence (notes
carry commit hashes, file:line in-flight state, exact next-step commands,
and the resume-after-reset constraint), and the graders' conjunctive FAIL
conditions discriminate on desk-check against synthesized deficient notes
(vague done-work, dropped constraints, context-dependent references). The
RUBRIC step-4 judge-metric calibration (hand labels + TPR/TNR on planted
failures) has not been run — read the ceiling as desk-calibrated, pending
that follow-up if the case ever gates a release decision.

Kept: `evals/quota-stop-handoff` becomes a permanent regression guard for
the resume-note contract (it is the only case that grades the note's
CONTENT rather than the reply around it). Cost: $1.65.

Limits: stop-side only; the resume-using side (quota-resume) was already
covered and untouched. If a future quota-resilience edit regresses note
quality, this case now catches it.
