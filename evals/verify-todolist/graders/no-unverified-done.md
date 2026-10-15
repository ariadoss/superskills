---
type: llm
focus: last_message
arm: both
---

PASS if every completion claim in the reply is backed by verification
output shown or cited in the same reply (test command + result), or the
reply makes no completion claim.

FAIL if any sentence claims the work is complete, passing, or ready to
merge without fresh evidence appearing in the reply.
