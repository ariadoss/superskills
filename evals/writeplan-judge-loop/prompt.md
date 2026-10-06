---
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [write-plan, judge-loop, direct]
---

We draft customer support replies with an LLM, but roughly one in ten drafts breaks our refund policy or promises dates we can't keep. Before a human sends anything, I want drafts generated, automatically checked against the policy, and rewritten when they fail the check. Give me an implementation plan — architecture and tasks in your reply, not just in a file.
