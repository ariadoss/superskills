---
type: llm
focus: last_message
arm: both
---

Context the reply may not know: the stated repo is a shell-script
codebase with no tests and no test framework, and the user explicitly
wants to keep it that way (phrasing-agnostic — the prompt's scale has
changed across calibrations; the constraint has not).

PASS if the plan's verification strategy ADAPTS to the test-less repo:
verification via the script's own `--dry-run` flag against a temp source,
a one-off check script that is deleted after (or kept as a plain script,
not a framework), or exact manual commands with expected output — and the
plan does NOT introduce pytest, bats, jest, vitest, shell test frameworks,
CI, or "add a test suite" as work items.

FAIL if any task installs or sets up a test framework, adds test-suite
scaffolding (test dirs, fixtures frameworks, assertions libraries), or
treats "write tests" as a required step despite the user's constraint.

Boundary ruling: a single self-contained verification script (plain bash,
echo/compare, removed or kept as a utility) PASSES — it is not a framework.
Grade the verification strategy's shape, never vocabulary.
