---
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [write-plan, plan-quality]
---

Our worker queue backs up when Stripe retries stack up. Plan the reconciliation job: a nightly pass over up to 500k pending webhook events, deduped by event id, reprocessed idempotently, processed in bounded batches, with an alert when an event keeps failing (poison event). Plan this for me — architecture and the task list in your reply.
