# PREREG — diff-walkthrough new-skill A/B (walkthrough-pricing)

Registered before any run of `walkthrough-pricing`. Provenance: cursor/plugins
`pr-review-canvas/skills/pr-review-canvas/SKILL.md` (MIT, © Cursor), adapted:
the canvas-SDK presentation layer dropped, the markdown presentation
conventions kept. Like the adopted 2026-10-07 cli-for-agent experiment (and
unlike the basic-review/clean-code skill-body edits), this is a NEW-SKILL A/B:
the skill itself is created only AFTER the baseline run — `claude plugin
eval .` loads skills from the repo working tree, so a
`skills/diff-walkthrough/` directory that is present but uncommitted would
still fire and contaminate the baseline.

## Intervention (applied only between the two arms)

The tree gains `skills/diff-walkthrough/SKILL.md` (full text in the plan) plus
its `./setup` link. There is no pre-existing skill behavior to improve from
within; the claim under test is that the skill's comprehension-first
presentation conventions add measurable walkthrough quality over what the
model produces unprompted.

## Cases

| Case | Role |
|---|---|
| `walkthrough-pricing` (new) | primary: the three outcome graders |
| `offtopic-no-skill` (unchanged) | global negative guard: no skill-firing in the treatment arm |

## Fairness rule (fixed in advance)

Graders grade presentation structure (which change leads, how depth is
allocated, whether boilerplate is summarized) and trace content (whether the
old-vs-new divergence carries a concrete input or outcome), never skill
vocabulary. skill-fired graders are unscored indicators. Boundary rulings are
in the grader texts, committed before runs. The fixture domain (pricing/tax)
is disjoint from the skill's examples (validator/routes — anti-leakage per
`evals/METHODOLOGY.md`).

## Endpoints and thresholds (set before the runs)

- Price calibration: one `--runs 1` run of `walkthrough-pricing`
  (`--max-cost-usd 5`). ABORT (keep cases, report the price) if it exceeds $4.
- Runs: `--ablation none`, 3 runs/case/arm, both arms same day. `--case` takes
  a single glob and `walkthrough-pricing`/`offtopic-no-skill` share no prefix,
  so each arm is TWO invocations: `walkthrough-pricing` at `--max-cost-usd 9`,
  `offtopic-no-skill` at `--max-cost-usd 3` (≤ $29 total with the price run).
- **Firing gate (treatment arm):** diff-walkthrough fires in ≥ 2/3 runs on
  `walkthrough-pricing`. Below that the experiment is VOID, not a reject: the
  skill is unreachable — report, revisit the description, do not adopt.
- **Primary:** mean of the three outcome graders (core-first,
  traces-divergence, wiring-connected) over 3 runs, change vs baseline.
- **Adopt** if: primary ≥ +0.15 AND traces-divergence alone ≥ +0.15 AND the
  firing gate holds AND `offtopic-no-skill` records no skill-firing in the
  treatment arm AND no outcome grader regresses ≥ 0.34 (a baseline run can
  pass a grader without the skill — the gates catch a skill that makes the
  walkthrough *worse*).
- **Reject** otherwise: remove `skills/diff-walkthrough/`, re-run `./setup`,
  keep case + PREREG, report the null. A null is a real answer.
- **Rider declaration:** the skill ships whole; the three graders sample its
  highest-risk behaviors (section ordering, divergence tracing, wiring
  connection). Pseudocode distillation, tricky-tags, and the
  ask-when-ambiguous rule are guarded only by the regression cases.
- Stated limit: n=3; same-day drift between the two sequential runs is an
  uncontrolled small confound (precedent: 2026-10-06 calibration report).

## Amendment 1 — registered after the baseline arm, BEFORE the treatment arm (2026-10-07)

The adopt condition "traces-divergence ≥ +0.15" is mathematically impossible:
the baseline arm measured traces-divergence at 1.000 (3/3 — the model already
traces old-vs-new divergences on a concrete input without any skill). The gate
was written expecting baseline weakness on tracing; that expectation was
wrong. Amended condition: traces-divergence does not regress ≥ 0.34 in the
treatment arm (the same no-regression form the other guards use). Everything
else — primary ≥ +0.15 (mean of the three outcome graders), treatment firing
≥ 2/3 (else void), offtopic clean, no outcome grader regressing ≥ 0.34 — is
unchanged. Disclosure: this amendment is registered with the baseline known
(0.667 / 1.000 / 0.000, primary 0.556) but before the treatment arm runs;
the deciding data does not exist yet. The skill's value proposition on this
fixture is now explicitly wiring-connected (baseline 0.000) and core-first
(0.667), not tracing.
