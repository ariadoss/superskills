# Design pack eval (2026-11-21)

> **Withdrawn, 2026-11-27.** The repo owner looked at the rendered pages from this eval, blind, and ranked the `new` arm top on 0 of 3 build tasks and last on one. The judge here read source only and reported `new` equal to `up`. The system numbers below do not stand. See `2026-11-27-design-pack-recheck.md`.

Question: do the concise `design-*` skills (arm `new`) work as well as Claude's originals (arm `up`) and better than no skill (arm `none`)? Method: `/eval`. Positive class everywhere: FAIL. Protocol and thresholds: `evals/design-pack/EVAL.md`, written before the runs.

## Eval set

6 cases (3 builds in new domains, B1 payroll build, F1 and F2 fix tasks), 3 arms, 30 pages, 4 dimensions (slop, hierarchy, states, honesty) = 120 labels. Selection: 4 negative controls and 4 near-misses.

## Judge (answer key: 48 labels, 9 FAIL)

| pass | TP | TN | FP | FN | TPR | TNR | accuracy | precision | bias |
|---|---|---|---|---|---|---|---|---|---|
| 1 (first rubric) | 5 | 35 | 4 | 4 | 0.5556 | 0.8974 | 0.8333 | 0.5556 | lenient (waved through 4/9 vs wrongly failed 4/39) |
| 2 (sharpened once) | 9 | 36 | 3 | 0 | 1.0000 | 0.9231 | 0.9375 | 0.7500 | harsh (wrongly failed 3/39 vs waved through 0/9) |

Pass 1 failed the gate (TPR >= 0.70). Pass 2 passes (TPR, TNR >= 0.70, gap 0.08 <= 0.20). Pass 2 disagreements: honesty on two B2 pages and states on one F2 page, all judge FAIL vs key PASS.

## System results (FAIL rate, 10 pages per arm, final run)

| dimension | none | up | new |
|---|---|---|---|
| slop | 0.50 | 0.00 | 0.00 |
| hierarchy | 0.00 | 0.00 | 0.00 |
| states | 0.60 | 0.10 | 0.00 |
| honesty | 0.50 | 0.50 | 0.50 |

First run failed the gate on slop, states and hierarchy. Fed back: design-states now names input hover, a disabled style for every submit and a success state for every form; design-slop-check now bans left borders on small success cards and requires a named font on fix tasks. The `new` arm was regenerated (10 pages) and re-judged with the same rubric. This is the one allowed rerun; no further iteration.

Gate reading (new <= up + 0.10 and new < none):
- slop: pass. states: pass.
- hierarchy: tie at 0.00 in all arms, so "new < none" cannot hold. No headroom, not a regression.
- honesty: tie at 0.50 in all arms. The skills do not move it. Failures are unlabelled specifics (turnaround times, "all 50 states", computed meal counts). Not fed back: treating it as a class needs its own cases.

So: new matches up on all four and beats none on slop and states. Strictly, the gate fails on hierarchy and honesty because of ties.

## Selection

0/4 negative controls picked a design skill; 4/4 near-misses routed right (design-review, a11y, plan-design-review, create-image). Gate passed.

## Limits

- The labeler is the session agent, not an independent human.
- The judge reads source only; temperature is uncontrolled.
- Only 9 FAIL labels in the key; n is small.
- Pass-2 rubric sharpening was done after seeing disagreements on the same 48 labels (in-sample).
- The rerun reused the same 6 briefs, so it is a retest, not a fresh sample.
- The regenerated `new` pages were not rendered; the judge saw source only.

## Top failure classes

System-only fonts on fix tasks; missing input hover and success states; left-border success card; competing filled buttons; unlabelled numeric claims (open).
