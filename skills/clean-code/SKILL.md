---
name: clean-code
version: 1.0.0
description: |
  Audit → fix → verify the branch diff against KISS, DRY, SOLID, and YAGNI.
  Finds duplicated logic, units with more than one reason to change, needless
  abstraction or speculative extensibility, wrong-altitude code, and dead code
  in the changed files — then applies the smallest safe refactor for each,
  one atomic commit per fix, under a green test suite. Quality only: it does
  not hunt for bugs (use /review or /code-review for that). Use when asked to
  "clean up the diff", "simplify this", "DRY this up", "refactor for SOLID",
  "remove duplication", "KISS", "YAGNI check", or "tidy before ship".
triggers:
  - clean code
  - clean up the diff
  - simplify this
  - dry this up
  - refactor for solid
  - remove duplication
  - yagni check
  - tidy before ship
argument-hint: '<optional: base branch (default auto-detect), --scope <paths>, or --report-only>'
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - Task
---

# /clean-code

Apply the superskills quality standard — **KISS, DRY, SOLID, YAGNI** — to the
code that changed on this branch, and prove each cleanup with tests. This is the
in-tree counterpart to Claude Code's built-in `/simplify`: it can be invoked from
inside any session or pipeline (`/qa-full` Step 3 runs it), and it works the same
in every tool `./setup` targets.

The principles are defined once, in `ENGINEERING_STANDARDS.md` in the superskills
install (a plugin install exposes it at
`${CLAUDE_PLUGIN_ROOT}/ENGINEERING_STANDARDS.md`). Read its DRY / SOLID / YAGNI
sections before auditing; do not expect the file in the project under review,
and do not flag it as missing. KISS is the standard's YAGNI + "smallest correct
change" rules applied to structure: the simplest design that passes the tests.

## Hard rules

- **Quality only.** This skill does not look for correctness bugs, security
  issues, or performance problems. If you notice one, record it as an
  out-of-scope note for `/review` / `/defense` and move on.
- **Diff-scoped.** Audit the files changed on the branch (`base...HEAD` plus
  the working tree). Refactoring untouched modules is itself a YAGNI violation.
  The one exception: when the diff duplicates a helper that already exists
  elsewhere, the fix is to *use* the existing helper, which may touch its file.
- **Behavior-preserving.** A cleanup changes structure, not behavior. Every fix
  runs under the existing tests; if the code you're restructuring has no test,
  write a characterization test first (`/tdd`), then refactor under green.
- **Smallest safe refactor.** Extract one helper, not a framework. Inline one
  needless indirection, not the whole module. Stop when the finding is gone.
- **Ground every finding in evidence:** file:line for each duplicate, the two
  responsibilities a unit mixes, the abstraction with one implementation, the
  config nobody reads. No "this feels complex."
- **One atomic commit per fix**, message naming the principle and the finding
  (e.g. `clean-code: DRY — extract parseRange() used by 3 call sites`). Never
  push.
- **Bounded.** One audit pass, one fix round, one verify pass. Report what's
  left as warnings — don't polish indefinitely.

## Step 1: Scope

1. Detect the base branch (`gh repo view --json defaultBranchRef -q
   .defaultBranchRef.name`, else `git symbolic-ref refs/remotes/origin/HEAD`,
   else `main`/`master`). `$ARGUMENTS` may name a base or `--scope <paths>`.
2. Changed files: `git diff --name-only <base>...HEAD` plus `git status
   --porcelain`. Keep only source files (skip lockfiles, generated code,
   vendored dirs, and pure docs unless docs are the deliverable).
3. Find the test command (`CLAUDE.md`, `package.json` scripts, `Makefile`,
   `pyproject.toml`); run it once. **If the suite is red, stop** — refactoring
   can't be verified on a red suite. Report and exit.
4. If `--report-only` was passed, do Step 2 and Step 4's report, skip Step 3.

## Step 2: Audit (report-only discovery)

Read every changed file in full, then check each of the following. Record
findings as `PRINCIPLE — file:line — evidence — smallest fix`, with severity
**HIGH** (duplicated logic, a unit doing two jobs that will diverge, dead code
on a live path), **MEDIUM** (wrong altitude, needless abstraction, speculative
config), or **LOW** (naming, ordering, minor simplification).

**DRY — one source of truth**
- Logic in the diff that already exists elsewhere in the repo. Grep for
  distinctive identifiers, string literals, and regexes from each new function
  before calling it new.
- The same logic written twice *within* the diff (two near-identical branches,
  two helpers with one differing argument).
- A rule or constant restated instead of referenced (also applies to docs and
  governance text).
- Knowingly-accepted duplication without an inline reason.

**SOLID — built to change**
- **S:** a function/class/module with more than one reason to change — name
  both responsibilities in the finding.
- **O:** a stable core edited with a new `if type == X` branch where a new
  implementation/strategy would do.
- **L:** an implementation that narrows or breaks its interface's contract
  (throws where the base returns, ignores a parameter the caller relies on).
- **I:** a wide interface where callers use two of eight methods; a parameter
  object passed only to read one field.
- **D:** a unit reaching for a concretion (`$HOME`, network, clock, global
  singleton, `new ConcreteThing()`) where a seam would make it testable in
  isolation.

**KISS — simplest thing that passes**
- Indirection with a single call site and no second implementation.
- Altitude mismatch: low-level detail inline in a high-level orchestrator, or
  business rules buried in a utility.
- Clever code where a plain loop/conditional reads in one pass (nested
  ternaries, reduce-as-control-flow, regex doing a parser's job).
- Cyclomatic hot spots: a function whose branches/early-returns exceed what a
  reader can hold; split by responsibility, not by line count.

**YAGNI — only what's required**
- Speculative extensibility: hooks, options, flags, config keys, abstract bases
  with one subclass, feature toggles nobody flips.
- Dead code: unreachable branches, unused exports/params/imports, commented-out
  blocks, TODOs describing work that isn't planned.
- Over-refactoring already in the diff: restructuring of code that had no
  reason to change.

Also note (not as findings) any *existing* helper you found that the diff should
reuse — that becomes the DRY fix.

## Step 3: Fix (skip with `--report-only`)

For each HIGH and MEDIUM finding, and any LOW whose fix is a one-liner:

1. If the code being restructured has no test that would catch a behavior
   change, write a characterization test first and watch it pass.
2. Apply the smallest safe refactor:
   - DRY → extract once, call from every site (or switch to the existing helper
     and delete the duplicate).
   - S/O/I/D → split by responsibility, introduce the seam, narrow the
     interface; keep public signatures stable unless the diff introduced them.
   - KISS → inline the single-use indirection, flatten the clever construct,
     move code to its right altitude.
   - YAGNI → delete the speculative hook/config/dead code; if the user might
     want it back, say so in the commit message rather than leaving it in.
3. Run the test suite. Green ⇒ commit atomically. Red ⇒ revert that one change
   (`git checkout -- <files>` / `git stash`) and record the finding as
   **UNFIXED** with the failing test name.

Do not touch findings outside the diff scope, and do not "improve" the tests
themselves beyond what a refactor needs.

## Step 4: Verify + report

1. Re-run the audit checklist on the changed files (now including your fix
   commits). Each fixed finding must no longer appear; the fixes must not have
   introduced a new duplicate or a new one-use abstraction.
2. Run the full test suite one final time on HEAD.
3. Print:

```markdown
# clean-code — <branch> @ <YYYY-MM-DD>
Base: <base>  Files audited: N  Suite: <command> → green/red

## Fixed (principle — finding — commit)
1. DRY — src/x.ts:40 duplicated parseRange() from src/util/range.ts — <sha>
- (or) None needed.

## Unfixed / deferred (with reason)
- SOLID/S — src/y.ts:12 mixes validation + persistence — needs interface change beyond the diff

## Warnings (LOW, left as-is)
- …

## Out of scope (hand to /review or /defense)
- …
```

Every fix lists a commit SHA; every unfixed finding lists why. No claim without
the re-audit and the fresh suite run behind it.

## Anti-patterns (do not do)

- Hunting bugs, security issues, or perf regressions — wrong skill.
- Refactoring code the diff didn't touch "while you're here."
- Extracting a helper for two lines used twice, or a base class for one
  subclass — that's trading a DRY smell for a YAGNI violation.
- Refactoring without a test that would catch a behavior change.
- Leaving a commit that mixes a refactor with any functional change.
- Pushing, opening PRs, or force-anything.
- Reporting "looks clean" without reading every changed file in full.

## Related commands

- `/review` — correctness / production-readiness review of the same diff; run
  it (or `/code-review`) for bugs, run this for quality.
- `/code-review` / `/simplify` — Claude Code built-ins with overlapping scope;
  use them when typing commands yourself. Pipelines and other tools use this
  skill because it's invocable everywhere.
- `/tdd` — the characterization-test-first discipline this skill's fixes follow.
- `/test-coverage` — writes the missing tests for logic this skill leaves
  untested.
- `/qa-full` — runs this skill in Step 3 as the quality half of the correctness
  pass.
- `/write-plan` — applies the same principles at plan time so there's less to
  clean up here.
