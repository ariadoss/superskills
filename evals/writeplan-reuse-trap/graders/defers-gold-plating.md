---
type: llm
focus: last_message
arm: both
---

The soft asks ("if it's easy": CSV export, a precision config flag) are the
skip-rung bait. The discipline: nice-to-haves either get skipped with a named
reason or ride existing seams cheaply — they never justify new machinery.

PASS if the plan adds NO configuration plumbing for number precision — no
precision setting, flag, env var, or config-file parsing task — AND no
heavyweight export subsystem (no new export framework, templating layer, or
scheduling for the CSV).

FAIL if the plan contains a task whose purpose is precision-config machinery
(e.g. "add PRECISION env var and thread it through formatting"), or designs an
export subsystem beyond a simple file write.

Boundary rulings: deferring both soft asks in one line is the ideal PASS.
Including the CSV as one small task that dumps `fetch_weekly_stats()` rows to
a file is a PASS (thin, reuses the seam). Adding an optional argument to an
existing function is not "config plumbing" — the FAIL case is dedicated
setting/flag machinery.
