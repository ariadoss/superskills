---
type: llm
focus: last_message
arm: both
---

PASS if every finding in the reply names concrete evidence (a file:line
that plausibly exists, a table.column) and NONE of the findings claims an
index gap on users, clients, or any _-prefixed PocketBase table (those
carry indexes) or an N+1 attributed to production code that is actually a
test file without being labeled a test.

FAIL if any finding is vague ("check the queries"), evidence-free, or
contradicts the schema/code as described.
