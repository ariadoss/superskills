# External review-technique adoption — consolidated verdicts (2026-10-07)

Six pre-registered A/B experiments adopting techniques researched from
auggie, review-pr/augment-agent, vercel-labs/open-agents, and cursor/plugins.
Method: the 2026-10-05 codex-adoption plan's discipline (PREREG committed
before any comparative run; n=3/case/arm, same day, with-plugin,
`--ablation none`; sonnet judge; per-grader pass-rate means; firing-power
gates; adopt/revert per pre-registered thresholds). Plan:
`docs/superpowers/plans/2026-10-07-external-review-adoption.md` (11 review
findings folded before execution). Branch: `external-review-adoption`
(worktree execution; the plan commit is `0ba528f`).

## Verdict table

| # | Technique (source) | Primary Δ | Decision | Spend |
|---|---|---|---|---|
| E1 | Repo-pinned conventions discovery (vercel-labs code-review) | +0.167 (gate ≥ +0.15 ✓) but no-false-positive 0.667→0.333 (zero-regression gate ✗) | **REJECTED** — precision trade | $4.69 |
| E2 | `REVIEW_GUIDELINES.yaml` opt-in contract (auggie) | 0.000 (gate ≥ +0.15 ✗) | **REJECTED** — flat; baseline already reads and cites the file unprompted (1.000 both arms) | $7.95 |
| E3 | "Code judo" ambition bar (cursor thermos) | names-judo 0.000→0.000 (gate ✗) | **REJECTED** — instrument defect recorded | $3.60 |
| E3b | E3 re-run, construct-faithful grader (registered addendum) | names-judo-v2 baseline 1.000 at ceiling | **NULL** — the model already does judo unprompted; change arm skipped per pre-registered branch | $1.61 |
| E4 | `cli-for-agent` skill (cursor/plugins, MIT, vendored) | +0.250 (0.750→1.000) | **ADOPTED** | $3.91 |
| E5 | `diff-walkthrough` skill (pr-review-canvas, adapted) | +0.111 (gate ≥ +0.15 ✗) | **REJECTED** — judge-calibration defect recorded | $2.32 |
| E5b | E5 re-run, repaired wiring grader (registered addendum) | +0.222 (0.556→0.778) | **ADOPTED** | $1.44 |
| E6 | qa-full cross-check synthesis (cursor thermos orchestrator) | −0.167 (synthesis-present 0.333→0.000) | **REJECTED** — regression, not noise | $8.51 |

**Total spend: $34.03 of the authorized $100.** Two adoptions ship: the new
skills `cli-for-agent` and `diff-walkthrough` (VERSION 2.42.0, minor — new
skills; main read 2.41.1 at ship time per the parallel-release rule).

## What the adoptions measured

- **E4 (`cli-for-agent`):** on a build-the-CLI task with evidence demanded in
  the reply, the skill moved `errors-actionable` 0.333→1.000 (fail-fast
  errors that include a correct invocation — the skill's most distinctive
  pattern) and `help-examples` 0.667→1.000; `non-interactive` and
  `repeat-safe` were already at ceiling in the baseline. Firing 3/3 in
  treatment (0/3 baseline — the skill-absent ordering rule held);
  `offtopic-no-skill` stayed clean (no false triggering).
- **E5b (`diff-walkthrough`):** `core-first` 0.667→1.000 (comprehension
  ordering — the skill's central instruction) and `wiring-connected`
  0.000→0.333 under the repaired differential grader (the baseline stayed
  0.000 under the same leniency, so the movement is the skill's).
  `traces-divergence` was at ceiling (1.000) in both arms both experiments —
  the model already traces old-vs-new divergences on concrete inputs; the
  skill's value is the *shape* of the walkthrough, not the math.

## Why the rejections happened (mechanisms, from open coding)

- **E1:** the conventions block fixed over-application on the conventions
  fixture (`no-convention-bleed` 0.000→0.333) but made no-findings replies
  elaborate pre-existing bugs past the precision grader's boundary
  (`no-false-positive` 0.667→0.333). Discovery instructions trade precision
  elsewhere — the adopted "What earns a finding" block already sits at the
  right trade-off for this skill.
- **E2:** dead flat. The model discovers and cites a root-level
  `REVIEW_GUIDELINES.yaml` unprompted (1.000 both arms); an instruction to
  read a file it already reads adds nothing, and the failure mode it targeted
  (over-application) did not move.
- **E3/E3b:** E3's grader admitted only the maximal reframe (a single
  spec-driven exporter) and failed all three change runs that had applied and
  named real category-deleting reframes (dispatcher if-chain → lookup table).
  The registered E3b re-run with a construct-faithful grader found the
  baseline at ceiling (1.000 without the skill): current models do judo
  unprompted on this fixture class; the ambition bar has nothing to add.
- **E6:** the thermos synthesis rule assumes two parallel reviewer lists that
  need merging; qa-full's passes are sequential (`/review`'s fix rounds
  complete before `/clean-code` starts), and the model's implicit
  one-root-cause reconciliation (1/3 baseline runs) *disappeared* under the
  explicit instruction (0/3). Negative delta, clean firing — a real
  misfit, not noise.

## Instrument incidents (all registered before their deciding runs)

- **E5 Amendment 1** (before the treatment arm): the `traces-divergence ≥
  +0.15` gate was mathematically impossible — the baseline measured 1.000.
  Amended to the standard no-regression form, with the baseline known and the
  deciding arm not yet run (disclosed in the amendment).
- **E3b / E5b addenda** (E5b before its baseline): judge/rubric repairs per
  METHODOLOGY's "every disagreement is a rubric bug before it is a model
  bug". Both repairs were differential (the repaired graders still scored
  0.000 where the behavior was absent) and both re-ran fresh both arms.
  E3b returned an honest null; E5b an adoption. One repair per instrument —
  no further re-runs were registered for E5b after adoption.

## Guard evidence

`review-calibration` (4 graders) held 1.000 in every arm it ran (E1/E2);
`offtopic-no-skill` stayed clean in every treatment arm (E4/E5); firing
gates held 3/3 wherever measured. Run errors: one max-turns exhaustion in
E3's baseline and one in E6's baseline (flagged, counted as failing all
scored graders per the PREREGs' stated rule).

## Costs

Per-arm actuals (JSON `costUsd`): review-case arms $2.11–3.89 for 9–15 runs;
cleancode arms $1.52–1.61; walkthrough arms $0.66–0.73; cli arms $1.26–1.56;
qa-full arms $3.38–4.19. All commands ran under their per-invocation
`--max-cost-usd` caps; no cap tripped. Each number above cites the
corresponding `evals/results/{conv,guidelines,judo,judob,cli,walkthrough,walkb,qaful}-{price,baseline,change}*.json`.

## Ship contents (2.42.0)

- `skills/cli-for-agent/` (new, vendored, MIT, `metadata.upstream` set)
- `skills/diff-walkthrough/` (new, adapted, MIT, `metadata.upstream` set)
- Six new eval cases + four new fixture libs + six PREREGs + three registered
  amendments, all retained as the instruments (and null records) for future
  re-tests.
- basic-review, clean-code, qa-full: **unchanged** (all three interventions
  reverted; verified by empty diff over the branch).

## Follow-ups (not blockers)

- `./setup` must run in the user's canonical checkout after merge — the two
  new skills are invisible to installs until then (recorded deviation:
  setup was not run inside the worktree).
- The E2 declared-untested edges (invalid-YAML fallback, glob scoping) remain
  unmeasured — the YAML contract was rejected, so no follow-up case is
  warranted unless the technique is revisited.
