---
type: llm
focus: last_message
arm: both
---

Ground truth: orders.user_id is the schema's ONLY un-indexed foreign key
(every other FK carries an index) and app/queries/orders_by_user.py
filters on it — the diagnosis the fixture plants.

PASS if the reply: names the missing index on orders.user_id (FK + query
filter), provides CREATE INDEX SQL for it, and does NOT rewrite either
query file in a way that changes results (a no-op note is correct — the
fix is the index; harmless query rewrites pass, wrong-SQL rewrites fail).

FAIL if the diagnosis names a different cause (missing index elsewhere,
wrong table) or no migration SQL is given.
