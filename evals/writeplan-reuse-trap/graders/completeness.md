---
type: llm
focus: last_message
arm: both
---

The required spec: a weekly email listing active users, stored files, and API
call volume, each human-friendly. (CSV export and a precision flag are soft
asks, not requirements.)

PASS if the plan covers ALL THREE required metrics and the email
assembly/delivery step, with some verification signal per task (a test or
command that says done).

FAIL if any of the three metrics or the email deliverable itself is missing
from the plan, or is deferred so vaguely no task produces it.

Boundary rulings: deferring or explicitly skipping the CSV export and the
precision flag is CORRECT and never a completeness failure — they are soft
asks. Including them as thin tasks that reuse existing stats is also fine.
