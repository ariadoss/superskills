---
max_turns: 30
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Bash, Skill]
tags: [dbmap, real-audit, maintainer]
---

The repo at ./fixture-repo is a Go hiring app with a sqlite database in
app.db (connection string in .env — the only connection; use it). Audit
its database performance: schema index gaps, N+1 query patterns in the Go
code, and heavy per-endpoint query paths. Reply with a prioritized
findings list — each finding with file:line or schema evidence — and
state clearly which are production code vs tests.
