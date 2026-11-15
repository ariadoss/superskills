---
max_turns: 15
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Bash, Skill, Write]
tags: [write-plan, reuse-first, smallest-change]
---

The repo is at ./fixture-repo. Plan this feature: a weekly dashboard summary email listing active users, stored files, and API call volume, each as a human-friendly number. If it's easy, a CSV export of the raw weekly stats and a config flag controlling number precision would be nice too. Architecture and tasks in your reply.
