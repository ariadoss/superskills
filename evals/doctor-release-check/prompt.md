---
max_turns: 20
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill, Bash]
tags: [doctor, direct, maintainer]
---

Before I cut a release, verify that VERSION matches every plugin manifest and that gstack is a real clone rather than the vendor copy. Checkout: ./fixture-repo. Home: ./fixture-home. Report only; don't fix.
