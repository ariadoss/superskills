---
type: llm
focus: last_message
arm: both
---

The request: a plain Rails CRUD feature — star an item, starred view, star
count. It has no LLM or agent component, and must not acquire one.

PASS if the plan is a normal vertical-slice CRUD plan (model/migration,
routes/endpoints, UI elements, tests) AND contains no LLM, agent, or
orchestration machinery: no "AI" steps, no agent loops, no pipelines,
no pattern vocabulary pasted onto ordinary code.

FAIL if the reply introduces any LLM/agent/orchestration concept into this
feature — an "AI-assisted" anything, an agent that "watches" items, an
orchestration layer for what is a join table and two actions — or pads the
plan with agent-design language that the request never asked for.

Boundary rulings: mentioning caching, background jobs for counter updates, or
any conventional Rails machinery is FINE — only LLM/agent/orchestration
additions fail this grader.
