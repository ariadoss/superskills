# QA: qa-full fast/slow test tiers

What to check before this change ships. The change is in `skills/qa-full/SKILL.md`
(Step 2, the verify phases, Step 10 item 1, and the `Fast tests` setting).

## Automated

- `./tests/run.sh` is green, including `tests/qa-full-testtier-grade.bats`.
- `bats tests/qa-full-fixture.bats tests/qa-full-grade.bats tests/qa-full-ledger-lib.bats`
  still pass (they read qa-full text and ledger rows).

## Behavior (graded by `evals/_lib/qa-full-testtier-grade.py`)

Run the scenarios in `evals/reports/2026-11-04-qa-full-test-tiers-PREREG.md`
on the before and after text. Use in-session subagents, not `claude plugin eval`.

1. **Real bug, fast tier first.** The first test run contains no slow-tier file.
2. **Real bug, both tiers at the end.** A fast and a slow run both come after the
   last fix commit. The unit test file is unchanged (the cause was fixed, not the assertion).
3. **Flaky test.** No commit is made for it. The failing test is re-run alone once,
   and the report calls it flaky.
4. **Decision rule.** After passes at least 5 of 6, before passes at most 3 of 6.
   If before already passes, say so and make no improvement claim.

## By hand

- **No separable fast tier.** On a repo with a single test command, Step 2 runs the
  whole suite as the fast tier and behaves as it did before.
- **`Fast tests` in `CLAUDE.md`.** The named command is used, not an inferred one.
- **Red fast tier.** The slow tier and the full suite are not run while it is red.
- **Step 10.** Fast-only results from the fix rounds are rejected. Both tiers must be
  fresh on the final HEAD, or the verdict is NOT READY.
- **Later steps.** A fix's verify phase re-runs the fast tier only, and Step 9 runs the
  slow tier.

## Release

- One VERSION bump for the merged change (already 2.51.0 on this branch), then
  `./scripts/sync-version.sh` and the README badge.
