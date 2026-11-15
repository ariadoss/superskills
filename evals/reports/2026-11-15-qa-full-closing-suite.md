# Result: qa-full closes with a pending verdict and one whole-suite question (2026-11-15)

Pre-registration: `2026-11-15-qa-full-closing-suite-PREREG.md`. Nothing in it changed after the runs.

## Results

| Arm | Run 1 | Run 2 | Run 3 | Passed |
|-----|-------|-------|-------|--------|
| before (`0c83bcd`) | fail | fail | fail | 0 of 3 |
| after (HEAD) | pass | pass | pass | 3 of 3 |

Decision rule (after at least 2 of 3, before at most 1 of 3): met.

Every before run ran the whole suite inline (the slow tier appears in `.testlog`),
wrote a plain `SHIP-READY` verdict and asked no question. Every after run ran only
the fast tier and the build, wrote `SHIP-READY ✅ (pending whole suite)`, and ended
on exactly one `QUESTION:` line about the whole suite. The hook's `qfl_has_verdict`
accepted all three after reports.

## What this does and does not show

It shows the new Step 10 text produces the new behavior and the old text does not. The
before arm failing is expected by construction, so this is a check that the edit took
effect, not proof it is better. It does not test the main-session failure that started
this work (ending a turn to wait on background reviewers or test runs); a subagent
cannot reproduce that. That rule rests on the skill text plus the hook change, which
`tests/qa-full-ledger-lib.bats` covers. Small n, Sonnet only, Step 10 only.
