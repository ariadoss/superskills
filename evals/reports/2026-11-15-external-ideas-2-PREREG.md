# PREREG — external ideas round 2 (ponytail ladder, blast-radius evidence, interrogate survivors)

Registered before any run. Provenance: all three sources MIT —
`DietrichGebert/ponytail` (fetched 2026-11-15), `cursor/plugins` pstack
(Lauren Tan, MIT), `cursor/plugins` cursor-team-kit (MIT, Copyright Cursor).
Ideas rewritten in our own words; nothing vendored. Prior round (2026-10-07,
v2.42.0) closed: code-judo in clean-code (E3b null at ceiling), thermo
synthesis in qa-full (E6 misfit), pstack micro-skills (granularity). Those are
not re-tested.

This round runs FREE in-session subagent A/B arms (user decision; no paid
`claude plugin eval` spend). Cases are committed as real harness cases for a
future paid confirmation.

## Interventions (applied only between the two arms)

### T1 — smallest-change ladder → `skills/write-plan/SKILL.md`

One subsection, "Before you plan the build — the smallest-change ladder",
placed at the end of Design Principles: for each task take the first rung
that fully works and name it — (1) not required: skip, one line why (soft
asks are skippable); (2) reuse what is already in this repo (the DRY rule as
an order, not a suggestion); (3) standard library / platform; (4) an
already-installed dependency — never a new one for a few lines; (5) a
one-line change; (6) only then new code — the minimum that fully works
including everything it must touch. Closing discipline: lazy about the
solution, never about the change — skipping a required piece is a plan
failure. Declared-unmeasured riders: rungs 3-5 ride unmeasured; the case
measures rungs 1-2.

### T2 — evidence grading → `skills/basic-review/SKILL.md`

Two edits. (a) In "What earns a finding", the speculation bullet is
strengthened: a cross-file/caller-impact claim needs `ran` or `read` evidence
— the run command's output or the specific affected caller `file:line` — or
it is DROPPED entirely (downgrading to a lower severity reintroduces
speculation; codex finding, accepted). (b) In Report, each finding carries an
evidence tier: `ran` / `read` / `reasoned`, where `reasoned` never supports
cross-file harm.

### T3 — survivor rule → `skills/qa-full/steps/10-final-verdict-report.md`

Added to Step 10 item 2 (re-audit): a re-audit concern survives into the
ledger only with fresh supporting evidence — a rerun whose output proves it,
or the specific code read (`file:line`) that demonstrates the harm; anything
else is recorded `dropped (unproven: <command tried>)`, never a finding. Two
guards from codex, accepted: inability to reproduce a reported failure never
clears it (the owning check's blocker stands until fixed or proven spurious);
and finding-one-caller is not proof of safety — the caller's own test/effect
must be checked.

## Cases

| Case | Role | Primary grader | Guards |
|---|---|---|---|
| `writeplan-reuse-trap` (new) | T1 primary | reuse-first | completeness, defers-gold-plating |
| `writeplan-overreach` (existing) | T1 no-regression | — | simplest-shape |
| `review-crossfile` (new) | T2 positive control: keep REAL cross-file findings | evidence-tagged | keeps-real-crossfile-bug |
| `review-calibration` (existing) | T2 speculation control | evidence-tagged | flags-introduced-bug, skips-speculation |
| `review-clean` (existing) | T2 negative control | evidence-tagged | no-false-positive |
| `qaful-survivors` (new) | T3 (isolated Step-10 construct) | proof-survivor | no-miss |

T3 validity caveat (user-accepted, D2=A): the case tests the Step-10
instruction in isolation — no pipeline hooks, no earlier steps. Full-pipeline
confirmation is a future paid run.

## Controls (fixed in advance)

- Arms differ ONLY by the injected skill-body text (complete skill directory:
  `SKILL.md` + `checklist.md` for basic-review; the step file for T3).
- write-plan's automatic `/plan-eng-review` chain is declared out of run
  scope, identically in both arms (the runner says "produce the plan; the
  automatic engineering-review handoff is out of scope for this run").
- Fresh subagent context per run; fixture rebuilt per run at a unique path;
  n=3 per arm per case; same session model both arms (identity recorded in
  the results report).
- Judging: blind judge subagents (arm labels stripped, shuffled order,
  rubrics only, no hypotheses visible); the author hand-labels every judged
  transcript; disagreement is a rubric bug before a model bug
  (calibrate.py: TPR/TNR/accuracy/precision, FAIL-positive).
- Artifacts: per-run transcripts kept under `evals/results/` (git-ignored).

## Fairness rule

Graders grade behavior (did the plan reuse, did the finding carry evidence,
did the concern die with proof), never vocabulary or formatting. Boundary
rulings live in the committed grader texts.

## Endpoints and gates (set before the runs)

Stated limit: n=3; scores move in 1/3 steps per grader per case. With equally
effective arms, treatment ≥ baseline + 1/3 about 34% of the time (codex
finding, accepted) — so adoption demands corroboration, not one flip.

- **T1 ADOPT iff:** reuse-first Δ ≥ +1/3 AND completeness Δ = 0 (no run lost)
  AND defers-gold-plating Δ ≥ 0 AND `writeplan-overreach`/simplest-shape Δ ≥ 0.
- **T2 ADOPT iff:** evidence-tagged mean Δ ≥ +1/3 across the three cases with
  no per-case Δ < 0 AND every guard holds (crossfile bug kept, calibration
  bug flagged, clean no-false-positive — none below baseline).
- **T3 ADOPT iff:** proof-survivor Δ ≥ +2/3 (two flips) AND no-miss = 3/3 in
  both arms.
- **REJECT otherwise:** revert the edit, keep cases + graders + this PREREG,
  report the null. A null is a real answer.
- Firing is not in question (bodies injected directly; routing stays the
  paid harness's question).

## Outside-voice findings and dispositions (codex, 2026-11-15)

1. T3 could clear non-reproducible blockers → fixed in edit text (never-clear
   guard). ACCEPTED.
2. T3 bait unproven (one caller ≠ safe) → caller's green test + grep both
   available in the fixture; guard added to edit text. ACCEPTED.
3. T2 had no positive cross-file case → `review-crossfile` added (real
   cross-module break, failing caller test). ACCEPTED.
4. T2 "downgrade" reintroduces speculation → edit changed to drop entirely.
   ACCEPTED.
5. T1 graded mention, not reuse → reuse-first rewritten: name-and-duplicate
   FAILs; dodging the decision FAILs. ACCEPTED.
6. One flip ≈ 34% noise at n=3 → corroboration clauses added to all three
   gates. ACCEPTED.
7. Uncontrolled dependencies → Controls section above. ACCEPTED.
8. T4 needs a defensible incident definition → see T4 below. ACCEPTED.

VERDICT from codex: FINDINGS (8) — all folded before any run.

## T4 — agent-mistake miner (groundwork only; no skill this round)

`evals/_lib/mine-agent-mistakes.py`, read-only over Claude Code `*.jsonl`
session logs. Incident definition (fixed in advance): (a) **edit-thrash** —
the same file edited ≥3 times within one session with an intervening failed
verification (test/build command exiting nonzero); (b) **repeat-fail** — the
same normalized command failing ≥2 times; (c) **skill-load-failure** — a
`Skill` tool_use resolving to an error result. Deduped by
(session, file|command) — a retry loop counts once. Deliverable: incident
counts + a hand-labelled precision sample of 20 drawn incidents (the report
labels each real/not-real and computes precision), then a build/no-build
recommendation for a `/correct`-style skill. Expected test failures inside a
TDD red-green flow are NOT incidents (the thrash definition requires the
failure to follow the edits, not precede them).
