---
max_turns: 24
timeout_seconds: 720
allowed_tools: [Read, Glob, Grep, Write, Edit, Bash, Skill]
tags: [dbmap, autooffer, maintainer]
---

Map the database at ./fixture-repo (sqlite app.db, connection in .env) with
/dbmap and tell me what you found.
