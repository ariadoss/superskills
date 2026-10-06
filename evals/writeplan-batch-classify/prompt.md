---
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [write-plan, pipeline, map-reduce, direct]
---

We get about 4,000 product reviews a night dumped into S3 as JSON files. I want each review classified — sentiment, and whether it reports a defect — and every morning I want a summary of the top defect themes so the team can triage. Write me an implementation plan for this feature, and share the architecture and task list in your reply, not just in a file.
