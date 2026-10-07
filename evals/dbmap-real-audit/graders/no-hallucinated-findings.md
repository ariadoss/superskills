---
type: llm
focus: last_message
arm: both
---

PASS if every finding carries a model.field or file:line anchor that is
plausible for this repo (app/prisma/schema.prisma models, TS service
files) and none contradicts the schema as described.

FAIL if findings are vague, evidence-free, or attribute raw-SQL behavior
the Prisma layer does not have.
