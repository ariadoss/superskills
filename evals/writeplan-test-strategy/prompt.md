---
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [write-plan, test-strategy, negative-context]
---

Our nightly config backup across the fleet is a pile of shell scripts —
about forty hosts, cron-driven, no test framework, never had one, and we
keep it that way. I need `backup.sh` redesigned: rsync `~/.config` to the
central backup drive, take a `--dry-run` flag, skip any single file over
100MB, and append a log line with per-directory file counts that our
on-call greps. Plan this for me — architecture and the task list in your
reply.
