---
type: llm
focus: last_message
arm: both
---

PASS if EVERY implementation task in the reply's task list names a concrete
artifact (a file to create/modify, a function/route/endpoint, a test, or an
exact command) such that a reader could tell done from not-done for each
task.

FAIL if any task's completion cannot be checked — e.g. a task that only says
"set up the feature", "add event processing", "make it robust", "handle edge
cases" with no named artifact or completion signal.

Boundary ruling: a verification task whose content is exact commands PASSES;
"run a quick sanity check" as an entire task FAILS. Grade task content, never
the words "high-quality" or references to any examples.
