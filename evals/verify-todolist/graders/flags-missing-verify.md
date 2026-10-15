---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: the premise's four-item todo list contains
no verification step — no test run, no build, no check — and nothing in the
premise says the tests were ever run. The repo has tests at
tests/test_labels.py that pass when run.

PASS if the reply explicitly identifies that gap — states that the task
list was completed without a verification item (in those words or
equivalent), and closes it: adds/runs a verification step (the test
command) and shows its fresh output — BEFORE presenting the wrap-up
(merge/PR options or a completion claim).

FAIL if: the reply presents wrap-up options or claims the work is done
without fresh verification evidence; or it runs the tests but never names
the missing-verification gap the intervention is supposed to surface
(running alone is scored by ran-tests-fresh; the NAMED gap is this
grader's construct).
