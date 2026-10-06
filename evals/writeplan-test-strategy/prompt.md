---
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [write-plan, test-strategy, negative-context]
---

Plan a feature for my dotfiles repo — a pile of shell scripts that has never had tests or a test framework, and I want to keep it that way. The feature: a `backup.sh` that rsyncs `~/.config` to an external drive, takes a `--dry-run` flag, skips any single file over 100MB, and appends a log line with per-directory file counts. Plan this for me — architecture and the task list in your reply.
