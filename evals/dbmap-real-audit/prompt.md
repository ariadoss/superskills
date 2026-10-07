---
max_turns: 30
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Bash, Skill]
tags: [dbmap, real-audit, maintainer]
---

The repo at ./fixture-repo is a Next.js payroll app with a Prisma schema
(app/prisma/schema.prisma) and a migration history under
app/prisma/migrations. Audit its database design for performance risks:
relations without supporting indexes, query patterns in the TS services
that look like N+1s or unbounded scans, and any per-endpoint heavy query
paths. There is no live database connection in this environment — work
from the schema, migrations, and code. Reply with a prioritized findings
list, each with file:line or schema-field evidence.
