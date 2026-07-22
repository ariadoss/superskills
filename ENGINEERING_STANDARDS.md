# Engineering Standards

The single source of truth for the quality bar every superskills command must
hold code to — both the code in this repo and the code the skills generate for
users. Skills **reference** this file rather than restating it, so the bar is
defined once and stays consistent (that is itself the DRY rule applied to
governance).

> **The bar:** code should be indistinguishable from what a strong engineer at
> Google or Meta would land — correct, tested, simple, and built to be changed.
> "It works" is the floor, not the bar.

These standards are **enforced, not aspirational.** `/qa-full` blocks on the
hard gates below; `/write-plan` bakes them into every plan; `/code-review`,
`/simplify`, and `/review` check against them; `/verify` confirms them before
anything is called done.

---

## TDD — tests come first, always

- **Red → Green → Refactor.** Write a failing test, make it pass with the
  minimal change, then refactor under green. No production code is written
  without a failing test that demanded it. (`/tdd` enforces the loop.)
- **Every new public function, branch, and error path has a test.** New public
  surface with zero tests is a **hard gate** — it blocks the ship (`/qa-full`
  Step 9).
- **Coverage target is concrete and stated**, not "good coverage." Default:
  ≥90% lines on new/changed modules, every error path exercised. Plans declare
  the target in their `## Test Plan & Verification` section.
- **Tests must actually run in CI / a runner.** A test that can't be executed
  doesn't count. Shell code in this repo is tested with `bats` via
  `./tests/run.sh`; application code uses the project's own runner.

## DRY — one source of truth

- Before adding code, **name the existing helper/module to reuse** (Grep for
  it). If you'd write the same logic twice, extract it once and call it twice.
- Duplicated logic across call sites is a **defect**, not a style preference.
  (Example in this repo: `scripts/lib/skills-lib.sh` exists because `setup` had
  the skill-linking logic copy-pasted across six per-tool blocks.)
- Knowingly-accepted duplication must be flagged with the reason inline.
- Applies to docs and governance too: define a rule once (this file) and link
  to it; don't paste it into every skill.

## SOLID — built to change

- **S — Single Responsibility.** Each unit has one reason to change. Name that
  responsibility for every new module/function in a plan.
- **O — Open/Closed.** Extend via new code; don't edit stable cores to bolt on
  variants.
- **L — Liskov.** Subtypes/implementations honor their interface's contract —
  no surprises when one is swapped for another.
- **I — Interface Segregation.** Keep interfaces narrow; callers shouldn't
  depend on methods they don't use.
- **D — Dependency Inversion.** Depend on abstractions/seams, not concretions —
  this is what makes units testable in isolation (see the `skills-lib.sh`
  extraction: pure functions with no `$HOME`/network coupling, so `bats` can
  test them hermetically).

## YAGNI — build only what's required

- Implement what the spec needs and nothing more. No speculative extensibility,
  no "might need it later" hooks, no config nobody asked for.
- Over-refactoring is a YAGNI violation too: don't restructure code you can't
  test or don't have a reason to touch.

---

## Hard gates (these block a ship — `/qa-full`)

A change is **NOT READY** if any of these is true:

1. A failing test or broken build.
2. New public surface with **zero tests** (TDD gate).
3. A `/code-review` CRITICAL/HIGH correctness finding.
4. A CRITICAL/HIGH security finding from `/defense`, `/fuzz`, `/pentest`, or
   `/iac-scan`.
5. An N+1 / missing index on a hot path (`/db-optimize`).
6. A CRITICAL/HIGH browser-QA bug in a user-facing flow.
7. A hard perf-gate breach, when `CLAUDE.md` defines one.
8. Tests/build not freshly run in the gate invocation (no stale "should pass").
9. A **triggered** security/perf check left unaccounted — neither run with
   evidence nor explicitly skipped with a stated reason. (Projects may mark a
   check MANDATORY in `CLAUDE.md`; then a skip is itself a blocker.)

Everything else (MEDIUM/LOW findings, non-hot-path perf, internal-helper test
gaps, style) is a **warning** that ships with a written follow-up note.

## Warnings (fix or consciously defer, with a note)

- DRY/SOLID smells that aren't yet defects (a second near-duplicate, a unit
  doing slightly too much) — fixed by `/simplify` / `/code-review`.
- Coverage below target on internal helpers.
- Naming, dead code, and altitude/abstraction-level inconsistencies.

---

## Where each standard is enforced in the workflow

| Stage | Command | Enforces |
|-------|---------|----------|
| Plan | `/write-plan` → `/plan-eng-review` | TDD tasks, DRY/SOLID/YAGNI structure, coverage target, Test Plan |
| Build | `/tdd` | Red-Green-Refactor loop |
| Review | `/code-review`, `/review` | Correctness + DRY/SOLID/efficiency on the diff |
| Cleanup | `/simplify` | DRY, simplification, efficiency, altitude (quality only) |
| Gate | `/qa-full` | The hard gates above → pass/fail verdict |
| Done | `/verify` | Verification commands actually pass before "done" |

See `DEVELOPER_WORKFLOW.md` for how these chain together per feature branch.
