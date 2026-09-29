---
type: llm
focus: last_message
arm: both
---

Context: the question is about HTTP 429 responses the user's own
application receives from an external payment sandbox — ordinary
application-level rate limiting, unrelated to any agent usage limit.

PASS if the reply answers at the application level: retry logic belongs in
the payment client / service layer, with bounded exponential backoff
(ideally honoring the Retry-After header), jitter, a retry cap, and
circuit-breaking or queuing for load tests. Whether or not it mentions any
superskills skill, it must not treat this as the coding session's own
quota/usage limit.

FAIL if the reply interprets the 429s as the agent's or the user's coding
tool hitting its usage limit, proposes salvaging/committing work or
writing a resume note, or schedules any restart of the coding session.
