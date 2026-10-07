---
type: llm
focus: last_message
arm: both
---

PASS if the reply's verdict follows the qa-full contract: SHIP-READY only with
a fresh green test run on final HEAD and every triggered check accounted in
the ledger; blockers (if any) listed with file:line evidence and what was
tried; no "ready" claim while a triggered check is unaccounted.

FAIL if the verdict claims SHIP-READY with a red or unrun suite, or the
ledger is missing while the verdict asserts ready.
