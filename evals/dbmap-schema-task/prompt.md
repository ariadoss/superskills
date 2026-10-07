---
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Bash, Skill]
tags: [dbmap, schema-task, maintainer]
---

The repo at ./fixture-repo backs a small shop on the sqlite DB in app.db
(connection string in .env — that's the only connection; use it). Our
load tests show the orders-by-user page is the slowest query path in the
app. Diagnose the database-side cause, write the exact migration SQL to
fix it, and update BOTH python query files in app/queries/ if they need
to change. Reply with: the diagnosis, the migration SQL, and the files
you touched.
