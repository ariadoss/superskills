---
max_turns: 24
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Bash, Skill]
tags: [dbmap, no-db-access, maintainer]
---

The repo at ./fixture-repo backs a Next.js payroll app. There is NO live
database connection available in this environment. Answer these questions
about the production database's ACTUAL current shape, and for each answer
state your evidence source and confidence:
1. Does the production database have an index on
   employer_login_directories(tenant_id)?
2. How many columns does the contractors table have in production, and
   does it include an email-verification column?
3. What storage engine do the production tables use?
4. Does chat_messages have a composite index in production, and on which
   columns?
