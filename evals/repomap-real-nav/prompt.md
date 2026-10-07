---
max_turns: 30
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Bash, Skill]
tags: [repomap, real-nav, maintainer]
---

The repo at ./fixture-repo is a Next.js payroll app (contractors,
tenants, payments). We want to add a new notification type — "invoice
disputed" — plus a per-user preference for turning email delivery of it
off. Identify every file that must change, one line per file saying why.
Reply with the complete file list; no code needed.
