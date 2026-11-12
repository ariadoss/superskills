## Step 9: Coverage pipeline — `/test-coverage` + `/playwright`

1. **Audit:** for each changed file (including this pipeline's fix commits),
   locate its test (sibling `*.test.*`, parallel `tests/`). Use coverage data if
   present (`coverage/`, `lcov.info`, `.coverage`); else do a structural check
   for new exported functions / branches / error paths without an assertion.
2. **Fix:** run `/test-coverage` on the diff — it writes and applies the missing
   unit tests (and integration tests where risk crosses a boundary), enforcing
   Google's Testing-on-the-Toilet practices. For **user-facing flows** with no
   e2e coverage, run `/playwright` to generate and run the e2e test so a
   regression test is left behind. Commit atomically.
3. **Verify:** run the new tests and the related tests; they must pass, and the structural
   check must show no new **public** surface with zero tests.

New public surface still untested after this step ⇒ UNFIXED blocker. Internal
helpers without tests are warnings.
