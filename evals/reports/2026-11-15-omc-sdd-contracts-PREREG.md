# Pre-registration: SDD feedback baseline, handoff files, assumptions ledger (2026-11-15)

Written before any run. Nothing below changes after results come in.

## Question

`skills/subagent-driven-development/` changed: Setup gained a **feedback
baseline** step (`scripts/feedback-baseline.sh`, itself bats-tested in
`tests/sdd-feedback-baseline.bats`), the dispatch/report contract gained a
**handoff file** and an **Assumptions** section, and DONE_WITH_CONCERNS +
Finish gained hard-to-reverse assumption handling. Does an agent following the
new text, set up against an already-red repo:

1. **Q1 (baseline):** record the pre-existing failure ids via the script
   (baseline file exists with the right ids) and say so in one line — where the
   old text has no baseline step at all?
2. **Q2 (dispatch contract):** compose a Task-2 dispatch that points at
   `task-1-handoff.md` (not the full task-1 report) and names the assumptions
   contract in the report-file instructions?
3. **Q3 (green repo, negative):** on a green repo, create NO baseline file
   (the step says a green repo gets no baseline)?

## Arms

- **before:** `skills/subagent-driven-development/` at `f4725f9` exported via
  `git archive` (no baseline script, no handoff/assumptions contract).
- **after:** the same tree at HEAD.
- Subagent: in-session Sonnet `general-purpose`, at most two at a time. Free
  under the plan.

## Scope of a run

The subagent plays the SDD controller for the Setup phase and one dispatch:
it is given a plan file (two trivial tasks), an SDD workspace, and a fixture
repo. It reads the exported skill, runs Setup (including the primary
verification command), and composes the Task-2 dispatch as a file after a
scripted "Task 1 is complete, review clean, here are its artifacts" state. It
must not dispatch real implementers — composing dispatches as files is the
deliverable.

## Fixture (evals/_lib/omc-sdd-fixture.sh)

A git repo with two test files: one failing test (`tests/login.js::rejects
bad token` — pre-existing red, unrelated to the plan's tasks) and one passing;
`package.json` with `npm test` as the verification command; a plan file whose
Test Plan names `npm test`. The green variant drops the failing test.

## Pass rules (graded by evals/_lib/omc-sdd-grade.sh)

- Q1 (n=3/arm): PASS when `<workspace>/feedback-baseline.tsv` exists, contains
  exactly the failing test's id, and the run's messages mention the
  pre-existing failure. before expected fail (no baseline file).
- Q2 (n=3/arm): PASS when the Task-2 dispatch file references
  `task-1-handoff.md` and does NOT reference `task-1-report.md`, and the
  dispatch or report-contract text mentions assumptions. before expected fail.
- Q3 (n=3, after only): PASS when no baseline file was created and the run did
  not fabricate pre-existing failures.

## Decision rule

Keep the SDD edits if Q1 after ≥2/3 with before ≤1/3, Q2 after ≥2/3, and Q3
≥2/3. On a Q2 miss, fix the dispatch-composition text and re-run Q2 only. On a
Q3 miss, tighten the baseline trigger ("if it reports failures") and re-run Q3.

## Known limits

Small n; Sonnet only; the run exercises Setup + dispatch composition, not live
implementer subagents (their side of the contract — writing handoff files and
assumption lines — is template text, whose effect is partially covered by Q2's
contract check). The script's own behavior is covered by bats, not here.
