# Pre-registration: qa-full closes with a pending verdict and one whole-suite question (2026-11-15)

Written before any run. Nothing below changes after results come in.

## Question

Two commits changed `skills/qa-full/SKILL.md` and `steps/10-final-verdict-report.md`:
Step 10 no longer runs the whole suite inline. It writes `VERDICT: SHIP-READY ✅
(pending whole suite)`, then asks the user once, as its last action, whether to run
the suite. Does an agent following the new text do that, and does the old text not?

## Arms

- **before:** `skills/qa-full` at commit `0c83bcd` (before both edits).
- **after:** `skills/qa-full` at HEAD, exported with `git archive` to the scratchpad.
- Each arm's folder is copied out and the subagent reads that path only.
- Subagent: in-session Sonnet `general-purpose`, at most two at a time. Free under
  the plan; `claude plugin eval` is not used.

## Scope of a run

Steps 1 to 9 are declared done, with every ledger row for them RAN-CLEAN (given in
the prompt). The subagent follows Step 10 only, skipping item 2 (re-audit) and
item 4 (no working branch), and writes the report to `qa-full-reports/`. No user
is available: where it would ask the user, it writes the question as the last line of
its final message, starting `QUESTION:`, and stops.

## Fixture (`evals/_lib/qa-full-closing-fixture.sh`)

The test-tier fixture's fixbug repo, with the bug already fixed in a final commit, so
`npm test` is green. `npm test` runs a fast and a 4 s slow tier; every test file logs
to the git-ignored `.testlog`. `CLAUDE.md` names `npm test` only.

## Pass rules (graded by `evals/_lib/qa-full-closing-grade.sh`)

A run passes when all four hold:

1. `.testlog` has no slow-tier entry (the whole suite did not run).
2. A report exists under `qa-full-reports/` whose verdict line matches
   `VERDICT: SHIP-READY.*pending whole suite`, and `qfl_has_verdict` accepts it.
3. The final message's last non-empty line starts with `QUESTION:` and names the
   whole suite, and it is the only `QUESTION:` line.
4. The fast tier (`tests/unit`) did run at least once (related tests + build still happen).

## Decision rule

n = 3 per arm. Keep the edit if **after** passes at least 2 of 3 **and** **before**
passes at most 1 of 3. If after fails, fix the skill text and re-run only after.

## Known limits

Small n; Sonnet only; Step 10 only. The before arm is expected to fail rules 1 and 2 by
construction, so this checks that the new text produces the new behavior, not that it
is better. A subagent cannot show the main-session failure (ending a turn to wait on
background work), so the "wait inside the turn" rule is not tested here; the hook
change that blocks verdict-less reports is covered by `tests/qa-full-ledger-lib.bats`.
