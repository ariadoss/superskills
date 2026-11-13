## Step 2: Tests & build (always — audit → fix → verify)

1. Find the project's test/build commands from `CLAUDE.md`; if absent, infer
   from `package.json` scripts, `Makefile`, `pyproject.toml`, etc. If you
   cannot determine them, they were part of the Step 1 batch (item 4a); if
   they went unanswered there, record SKIPPED("no test/build command known")
   for this step rather than guessing and running an arbitrary command.
2. **Run only the tests that cover the changed files (the related tests).**
   Map the changed source files from Step 1 to their tests: the test files in
   the diff, plus tests that import or name a changed module (grep the test
   tree for the module or function names), plus a runner selector where one
   exists (`jest --findRelatedTests <files>`, `vitest related <files>`,
   `pytest <test files>`, `go test <changed packages>`, `bats <matching files>`).
   Run those by name, plus the build. The whole suite does not run in this step
   or in any step before Step 10: fix the obvious breakage with the cheap run
   first. If no related test can be found, say so in the ledger row and run the
   project's unit-only command (`Fast tests` in `CLAUDE.md`, `test:unit`,
   `pytest -m "not slow"`, `go test -short`) instead.
3. **Audit:** run the related tests and the build. Fail fast: stop at the first
   red run. Capture exact failures (test name + verbatim error in a code
   block). While anything is red, never run the whole suite (`npm test`,
   `make test`, or any chained command that falls through to it); re-run one
   failing test by name.
4. **Flaky check:** before treating a failure as real, re-run just that test
   once on its own. Passes on re-run ⇒ record it as FLAKY (a warning, with the
   test name), not as a fix target. Fails again ⇒ a real failure. Never
   re-run the whole suite until it goes green.
5. **Fix:** for each real failing test or build error, follow `/debug` —
   reproduce, root-cause, then fix the cause (not the assertion). Commit each
   fix.
6. **Verify:** re-run the related tests and the build. Green ⇒ FIXED(n). Still
   red after two rounds ⇒ UNFIXED blocker with the failing test and what was
   tried. Every later step's verify phase re-runs the related tests for the
   files it touched, never the whole suite. The whole suite runs once, in Step
   10, on the final HEAD after every fix has landed. A failure there is fixed,
   the related tests re-run, and the whole suite runs again, until green.

If this step ends UNFIXED after two rounds, **stop here** and report NOT READY
with the failing test. Every later step's verify phase depends on a green
suite — running fixers on a red suite is fix → hope, not fix → verify. Mark
every downstream ledger row `SKIPPED("pipeline halted at Step 2")`. A working
branch from Step 1.5 stays as-is (base untouched) so the fix commits are there
for the user.
