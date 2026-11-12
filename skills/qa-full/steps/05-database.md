## Step 5: Database pipeline — `/db-optimize` (auto-run if triggered)

Trigger when the diff touches ORM models, migrations, schema or statement
modules, query builders, `*.sql`, raw SQL, or new ORM calls, in any language.
Folder names like `**/models/**` are only examples: a Python repo keeps its
database code in files like `schema.py` or `statements.py`. Decide with the
`db` trigger helper in `SKILL.md`, not by eye.

1. **Audit:** run `/db-optimize` scoped to matched files (run `/dbmap` first if
   it asks for a schema map).
2. **Fix:** N+1s on hot paths → eager-load/batch (`includes`/`preload`/
   `select_related`/dataloader); missing indexes on hot paths → add a migration
   for the index; obviously-redundant queries → dedupe. Add a test that asserts
   the query count where the ORM supports it. Commit atomically.
3. **Verify:** re-run `/db-optimize`; the hot-path findings must be gone and
   the migration must apply cleanly in the test run.

Non-hot-path suggestions are warnings (fix if trivial). No trigger ⇒
NOT-TRIGGERED.
