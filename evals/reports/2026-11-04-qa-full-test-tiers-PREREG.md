# Pre-registration: qa-full fast/slow test tiers (2026-11-04)

Written before any run. Nothing below changes after results come in.

## Question

The edit to `skills/qa-full/SKILL.md` splits Step 2 into a fast tier (unit
tests, run first, fail fast) and a slow tier (everything else, Step 9 and
Step 10). It also adds a single-test rerun to classify flaky failures. Does an
agent following the new text behave that way, and does the old text not?

## Arms

- **before:** `git show HEAD:skills/qa-full/SKILL.md` (the committed text).
- **after:** the working-tree `SKILL.md`.
- Each arm's text is copied to the scratchpad and the subagent is told to read
  that path, so the live skill file and the dirty tree cannot leak into a run.
- Subagent: in-session Sonnet `general-purpose`, at most two at a time. Free
  under the plan; `claude plugin eval` is not used.

## Scope of a run

The subagent follows Step 2 and Step 10 item 1 only (Step 1 is done: it is on
`feature/checkout`, tree clean). Other steps are skipped by instruction. This
tests the changed steps, not the whole pipeline.

## Fixture and scenarios (`evals/_lib/qa-full-testtier-fixture.sh`)

Plain Node repo. `npm test` runs both tiers; `npm run test:unit` is the fast
tier; `npm run test:slow` is the slow tier (a 4 s test). `CLAUDE.md` names
`npm test` only, so the fast tier must be inferred from `package.json`. Every
test file appends `ms tier file` to the git-ignored `.testlog`.

- **fixbug:** the feature commit has a real bug and a failing unit test.
- **flaky:** no real bug; one unit test fails on its first run and passes on
  every later run.

## Pass rules (graded by `evals/_lib/qa-full-testtier-grade.py`)

- **fixbug passes** when all three hold:
  1. the first test run group in `.testlog` contains no slow-tier file;
  2. a fast-tier and a slow-tier entry both come after the last commit
     (both tiers on the final HEAD);
  3. `npm run test:unit` is green at the end and the unit test file is unchanged
     from the feature commit (fixed the cause, not the assertion).
- **flaky passes** when all three hold:
  1. HEAD is the fixture's original HEAD (no commit made for a flake);
  2. a later run group exists that ran only the flaky test file;
  3. the report mentions "flaky" (case-insensitive).

## Decision rule

n = 3 per scenario per arm (12 runs), pooled per scenario.

- Ship the edit if **after** passes at least 5 of 6 pooled across both
  scenarios **and** **before** passes at most 3 of 6. A before-arm that already
  passes means the edit adds nothing measurable on that behavior; report it and
  do not claim an improvement.
- If after fails a rule, the fix is to the skill text, then re-run that
  scenario only.

## Known limits

Small n; Sonnet only; truncated pipeline; the before arm may pass by habit
(running the unit tests first is natural). All reported as found.

## Addendum (written before the re-run; the first results are unchanged)

The first run showed two after-arm runs (fixbug-2, fixbug-3) running the whole suite
once on a red tree by accident, which rule 1 (first run group only) cannot see. Step 2
now says never to run the full suite while the fast tier is red, and the grader adds:

- **fixbug rule 4:** no slow-tier file starts before `discount.test.js` first exits 0
  (the moment the fast tier first goes green). Each test file now also logs
  `end-<tier> <file> <exit-code>` at exit, so this is read from the log, not guessed.
  Part of `pass`. (A first version keyed on the fix commit's time; it gave false
  positives because agents verify a fix before committing it, so it was dropped before
  any after2 run.) Runs from before this addendum have no exit records, so rule 4 does
  not apply to them (graded `n/a`).

Re-run: arm `after2` (the SKILL.md with the new Step 2 sentence), fixbug scenario only,
n = 3. Adopt the sentence if after2 passes all four rules in 3 of 3 runs. The earlier
12 runs keep their three-rule grades; the flaky scenario is not re-run (the
sentence does not touch that behavior).
