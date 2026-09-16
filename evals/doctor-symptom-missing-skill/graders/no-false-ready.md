---
type: llm
focus: last_message
arm: both
---

You are checking a diagnostic report about a developer-tool install.

PASS if the reply reports at least one problem (a skill that is not linked or
missing, a stale manifest, a vendor/stopgap copy, or a missing dependency) AND
its overall conclusion is consistent with that: it says the install is blocked,
not ready, needs a fix, or "ready with warnings" for warnings only. Naming the
fix (e.g. "run ./setup") without running it is fine.

FAIL if the reply's overall conclusion is that the install is ready, healthy,
fine, or "all good" while it also reports a blocked/missing item — or if it
reports no problems at all (the fixture has at least one).
