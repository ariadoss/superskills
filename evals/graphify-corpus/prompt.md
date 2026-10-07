---
max_turns: 30
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Bash, Skill]
tags: [graphify, corpus, maintainer]
---

The folder ./fixture-repo is a content site repo (product docs, design
docs, a writing style guide, todos/handoffs, and a content tree). Answer
from the corpus, with evidence (file names / quoted lines):
1. What is the offering, who is the audience, and what differentiators
   are claimed? (cite the doc)
2. What are the site's voice rules? List at least three actual rules.
3. Which top-level docs reference each other, and on what topics?
4. What work is currently open or in flight? List at least three items.
