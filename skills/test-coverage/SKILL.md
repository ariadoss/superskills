---
name: test-coverage
version: 1.0.0
description: |
  Finds complex business logic, edge cases, corner cases, and past regressions
  that lack tests, then writes the missing unit tests (and integration/E2E
  tests when the risk genuinely crosses a boundary) — enforcing Google's
  Testing on the Toilet best practices (real > fake > mock, don't mock types
  you don't own, verify state not queries, avoid change-detector tests, DAMP
  over DRY in tests, limit mocks per test). Use when asked to "add tests",
  "cover edge cases", "check test coverage", "write missing tests", "harden
  the tests", "test this properly", or "make sure this is tested".
triggers:
  - add tests
  - cover edge cases
  - check test coverage
  - write missing tests
  - harden the tests
  - test this properly
  - make sure this is tested
argument-hint: '<optional: paths/globs to scope, or --full for the whole repo>'
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - Task
---

# /test-coverage

Finds where complex business logic, edge cases, corner cases, and past
regressions are undertested, then **writes and applies** the missing tests —
unlike `/qa-full` Step 9, which only drafts a sample test as evidence for a
ship/no-ship verdict. This is the fixer; `/qa-full` is the gate.

## Hard rules

- **The bar is `ENGINEERING_STANDARDS.md`'s TDD section** (referenced, not
  restated): every new public function, branch, and error path needs a test;
  ≥90% lines on new/changed modules is the default target; a test that can't
  run in the project's real runner doesn't count.
- **A failing test against existing code is a finding, not noise.** If a test
  you write to cover a "should never happen" case actually fails, you found a
  real bug or an already-broken regression — report it with repro evidence and
  do **not** rewrite the test to match the broken behavior. Fix the test's
  scope only when the *spec* was wrong, never to paper over a real defect
  without telling the user.
- **Every test you write or touch follows the Google practices in Step 5** —
  this is not optional flavor text, it's the acceptance bar for the tests this
  skill produces.
- **Smallest correct test level.** Default to unit. Escalate to integration or
  E2E only per the pyramid rule in Step 4 — don't reach for Playwright to
  cover a pure function.
- **Ground every gap in evidence**: file:line of the untested logic, the
  specific input class missing coverage, and (for regressions) the commit that
  introduced the bug.

## Step 1: Scope

1. If `$ARGUMENTS` gives paths/globs, scope to those. If it says `--full`,
   scope to the whole repo. Otherwise default to the current branch's diff:
   `git diff --name-only <base>...HEAD` plus `git status --porcelain`
   (same base-branch detection as `/qa-full` Step 1).
2. Detect the test framework and runner from the project (`package.json`
   scripts, `pytest.ini`/`pyproject.toml`, `go test`, `bats`, `*.csproj`,
   `Gemfile`). If ambiguous, ask rather than guess — writing tests against the
   wrong runner is worse than asking one question.
3. Record scope, runner, and command at the top of your working notes.

If the scope is empty, say so and stop — there's nothing to cover.

## Step 2: Find undertested complex logic

For each in-scope file, flag functions/methods that are "complex" by any of:

- **Multiple branches** — 2+ `if`/`switch`/ternary paths, especially ones that
  return different values or take different side-effecting actions.
- **Loops with accumulation or early exit** — aggregation, search, dedup,
  pagination.
- **State machines / status transitions** — anything with an enum of states
  and rules about which transitions are legal.
- **Calculations with domain rules** — money/currency, dates/timezones,
  permissions/authorization, rate limiting, parsing/serialization, validation.
- **Recursive functions.**
- **Anything already flagged by `/db-optimize`, `/perf-profile`, or a prior
  `/code-review` as high-risk** — risk-driven prioritization: spend the
  budget here first, not on trivial getters.

For each, grep the test tree for a reference to that function/class name. No
reference (or only a shallow "doesn't throw" smoke test) ⇒ gap.

## Step 3: Enumerate edge and corner cases per gap

For each gap from Step 2, work out the input-partition classes relevant to
*that* logic — don't apply a rote checklist blindly, reason about what this
function actually branches on. Common classes to check against:

- null / undefined / missing-key vs. present-but-empty (`""`, `[]`, `{}`, `0`)
- boundary values: zero, negative, max/min of the type, off-by-one at a
  loop/array edge
- single-element and duplicate-element collections
- malformed / unexpected-shape input (extra fields, wrong type, truncated)
- concurrent or repeated calls (double-submit, idempotency)
- unicode/encoding edge cases in string handling
- timezone/DST boundaries and leap years in date logic
- floating-point precision in money/percentage math
- combinations of two+ conditions that individually pass but together hit an
  unhandled branch (the actual "corner" case, not just one axis at a time)

Only list classes that are **reachable** through the function's real callers —
don't invent tests for input shapes the type system or a validator already
rules out upstream.

## Step 4: Regression coverage

1. `git log` the in-scope files for commits whose message matches
   `fix|bug|regression|hotfix|revert` (case-insensitive).
2. For each match, check whether that commit (or a nearby one) added or
   modified a test. No test touched ⇒ **regression gap**: the bug could
   reappear silently.
3. For each regression gap, write a test that reproduces the *original*
   failure mode (read the pre-fix diff to know what broke) and pins the fixed
   behavior — the classic "this test would have caught it" test.

## Step 5: Decide the test level — pyramid, not instinct

- **Unit (default).** The logic's correctness can be verified with real
  objects/pure functions and no I/O. This is nearly everything from Steps 2–4.
- **Integration.** Escalate only when the *real risk* lives at a boundary a
  unit test would fake away — an actual SQL query's behavior, a real
  filesystem/queue interaction, a multi-module contract. Prefer a real
  dependency or an in-process fake/hermetic server over mocking the boundary
  (see [`rules/real-fake-mock-hierarchy.md`](rules/real-fake-mock-hierarchy.md));
  reach for a mock only when no hermetic option exists.
- **E2E.** Reserve for a small number of critical golden-path user journeys
  where the risk is the *wiring between* already-unit-tested pieces, not any
  single piece's logic. Use `/playwright` for browser E2E — don't hand-roll a
  driver here.
- State which level you chose per gap and why in one line — this is the
  artifact a reviewer checks when they ask "why is this an integration test."

## Step 6: Google testing best practices (apply to every test you write)

These are Google's Testing on the Toilet rules that close real gaps in most
test suites. Each is a short standalone file under `rules/` — a rule plus a
concrete good/bad example — so you pull in the detail only for the rule that's
actually in play, instead of re-reading all eleven every run. Skim the
one-liners below; open a file when its situation applies to the test you're
about to write. When you're already touching an existing test for a nearby
reason, fix violations you see rather than adding a `TODO`.

| Rule | Applies when |
|---|---|
| [`real-fake-mock-hierarchy.md`](rules/real-fake-mock-hierarchy.md) | About to reach for a mock — check real/fake first |
| [`dont-mock-types-you-dont-own.md`](rules/dont-mock-types-you-dont-own.md) | The dependency is a third-party type, not your own |
| [`verify-state-changes-only.md`](rules/verify-state-changes-only.md) | About to `verify()`/assert-called-with on any call |
| [`state-over-interaction-testing.md`](rules/state-over-interaction-testing.md) | Choosing what the assertion should check |
| [`avoid-change-detector-tests.md`](rules/avoid-change-detector-tests.md) | The test's structure is starting to mirror the code's branches |
| [`know-your-test-doubles.md`](rules/know-your-test-doubles.md) | Picking which kind of double to use |
| [`limit-mocks-per-test.md`](rules/limit-mocks-per-test.md) | The test already has 2+ mocks |
| [`damp-not-dry.md`](rules/damp-not-dry.md) | Tempted to extract a shared fixture/setup helper |
| [`test-behaviors-not-methods.md`](rules/test-behaviors-not-methods.md) | Naming a test or deciding how many tests one function needs |
| [`inject-dont-hardcode-statics.md`](rules/inject-dont-hardcode-statics.md) | The gap traces back to a singleton/static/`Date.now()` |
| [`descriptive-names-clean-data.md`](rules/descriptive-names-clean-data.md) | Naming a test or building its fixture data |

## Step 7: Write the tests

For each confirmed gap (Steps 2–4), at the chosen level (Step 5), following
the Step 6 `rules/` checklist:

1. Write the test. Run it. If it's testing genuinely new behavior it should
   fail first (red) against a stubbed-out expectation, or pass immediately
   because the behavior already exists and you're only closing a coverage
   gap — either is fine, but **run it and read the actual result**, don't
   assume.
2. If a new test fails against unmodified production code, stop and report it
   as a bug/regression finding (see Hard rules) instead of silently adjusting
   the assertion.
3. Apply the test file changes (this skill writes and commits to the working
   tree, unlike `/qa-full`'s draft-only Step 9).

## Step 8: Run the full suite and report

Run the project's real test command. Then report:

```markdown
# Test coverage — <scope> @ <date>

Runner: <command>   Files scoped: N   New tests added: M

## Gaps closed
- <file:line> <function> — <input class(es) covered> — <unit|integration|e2e> — <test file:line>

## Regressions pinned
- <original bug commit> — <file:line> — reproduces: <what broke> — <test file:line>

## Bugs found while writing tests (not fixed here)
- <file:line> — <test that exposes it> — <why it's a real defect, not a bad test>

## Best-practice fixes applied to existing tests touched
- <file:line> — <which rules/ file> — <what changed>

## Suite result
<pass/fail summary from the real run>
```

## Anti-patterns (do not do)

- Writing a mock for a dependency you own instead of just using the real
  thing or a fake (`rules/real-fake-mock-hierarchy.md`).
- Mocking a third-party type directly instead of wrapping it
  (`rules/dont-mock-types-you-dont-own.md`).
- `verify()` on a getter/query call (`rules/verify-state-changes-only.md`).
- A test that re-implements the production branching logic to compute its
  expected value — that's not a test, it's a mirror
  (`rules/avoid-change-detector-tests.md`).
- Reaching for Playwright/E2E to cover a pure function that a unit test
  covers in milliseconds (Step 5).
- "Fixing" a failing test by loosening its assertion to match a real bug,
  without telling the user (Hard rules).
- Padding the report with trivial getter/setter coverage while a genuinely
  complex branch stays untested — risk-driven prioritization (Step 2).

## Related commands

- `/tdd` — the write-code-first-with-a-failing-test loop *while implementing
  new code*. `/test-coverage` runs *after* code exists, to close gaps in what
  already landed.
- `/qa-full` Step 9 — the read-only gate check ("is there a coverage gap
  blocking ship"). Recommend `/test-coverage` from there to actually close
  gaps rather than just draft one sample test.
- `/playwright` — the E2E harness this skill hands off to when Step 5 decides
  a gap needs browser-level coverage.
- `/code-review` — correctness review of the diff; `/test-coverage` is the
  complementary "does the diff have adequate tests" pass, and can be run right
  after a `/code-review` pass identifies risky logic.
- `/debug` — when Step 7 surfaces a real bug via a new test, use `/debug` to
  root-cause and fix it (this skill reports the bug, it doesn't fix production
  code).
