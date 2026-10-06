---
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [write-plan, test-strategy, negative-context]
---

Our ops repo is a pile of shell scripts — no test framework, never had
one, and we keep it that way. I need a `backup.sh` that rsyncs `~/.config`
to the external drive, takes a `--dry-run` flag, skips any single file
over 100MB, and appends a log line with per-directory file counts. Plan
this for me — architecture and the task list in your reply.
