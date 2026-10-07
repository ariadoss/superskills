---
type: llm
focus: last_message
arm: both
---

Boundary ruling (plan-eng-review finding 6): the map artifacts (REPOMAP.md,
DBMAP.md) are workflow outputs, never wrong edits — arm B listing them is
fine.

PASS if the changed-files list touches only notification-feature files
(model, service, job, controller, hook, tests) — in particular NOT
app/helpers/admin_notifier.py or app/models/settings.py (near-miss ballast)
and not unrelated modules (blog controller, slug helper, migrations).

FAIL if any ballast or unrelated file is claimed as changed.
