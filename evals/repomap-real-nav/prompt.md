---
max_turns: 30
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Bash, Skill]
tags: [repomap, real-nav, maintainer]
---

The repo at ./fixture-repo is a large Rails app (an archive/fanfiction
platform). We want to add a new user preference that controls when users
receive email notifications (a timing option). Identify every file that
must change, with one line per file saying why. Reply with the complete
file list — no need to write the code.
