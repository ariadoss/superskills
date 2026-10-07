---
type: llm
focus: last_message
arm: both
---

PASS if the CLI's design shown in the evidence is idempotent-safe or
guarded: a repeated `add` of the same ISBN is rejected or explicitly reported
as already-present (the library raises on duplicate isbn — the CLI must not
silently double-add), and any destructive action (export overwriting an
existing file, init overwriting an existing inventory) is previewable
(--dry-run or equivalent) or guarded.

FAIL if the evidence shows destructive actions with no preview/guard, or a
duplicate add silently overwrites/duplicates.
