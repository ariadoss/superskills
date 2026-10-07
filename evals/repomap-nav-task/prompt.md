---
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Bash, Skill]
tags: [repomap, nav-task, maintainer]
---

The repo at ./fixture-repo has a notifications feature with a priority
concept that is currently dead weight: Notification.priority is set to 1
and never read. Make priority real end to end: callers must be able to
pass an urgent priority, and EVERY place that currently creates or sends
a Notification must carry it through. Don't touch anything unrelated.
Reply with the files you changed and one line each on what changed.
