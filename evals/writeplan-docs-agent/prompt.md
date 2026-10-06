---
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [write-plan, agent-loop, symptom]
---

Our API docs keep drifting out of sync with the code. I want a feature that watches the repo, figures out which docs pages are stale, and opens a PR with the updates. The hard part: I can't enumerate the steps in advance — it has to decide what to read and what to rewrite as it goes. Plan this for me and share the architecture in your reply, not just in a file.
