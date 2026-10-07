---
type: llm
focus: last_message
arm: both
---

Boundary ruling (carried from the repomap experiment): DBMAP.md is a
workflow output, never a wrong edit — arm B listing it is fine.

PASS if the changed-files list touches only files under app/queries/
plus at most a migration/SQL file the reply itself defines (a new
migration file it names and shows the SQL for) — NOT app/models/,
scripts/, tests/, README.md, .env, or schema DDL of unrelated tables.

FAIL if any changed file outside app/queries/ is claimed beyond that
self-defined migration file — concretely: app/models/order.py,
scripts/repl.py, README.md, .env, or any table's DDL other than the
orders index.
