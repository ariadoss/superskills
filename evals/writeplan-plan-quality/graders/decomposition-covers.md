---
type: llm
focus: last_message
arm: both
---

PASS if the plan treats these as explicitly addressed, separable concerns:
1) volume at 500k events (bounded batches, chunking, or cursor-style
   pagination — not loading all events into memory), 2) dedupe keyed on the
   event id, 3) idempotent reprocessing (an event applied twice has the same
   effect as once), and 4) a poison-event path (bounded retries, then alert
   or quarantine), plus a test exercising volume or batching behavior.

FAIL if any of the four concerns is absent, or if the plan loads all events
into memory in one pass with no bound.
