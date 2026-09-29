---
max_turns: 20
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill, Bash]
tags: [quota, negative, app-behavior]
---

Our payment-service client in this repo (./fixture-repo) keeps getting
HTTP 429s back from the payment sandbox during load tests. Where should the
retry logic live and how should it back off?
