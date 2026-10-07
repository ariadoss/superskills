---
max_turns: 15
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Bash, Skill, Write, Edit]
tags: [cli-for-agent, quality]
---

The repo at ./fixture-repo needs the `shelfy` CLI built (spec in its README, logic in inventory.py). Build it so both humans and coding agents can drive it, then show me the evidence: the `--help` output, what a missing-required-flag run prints, and what a successful `add` prints.
