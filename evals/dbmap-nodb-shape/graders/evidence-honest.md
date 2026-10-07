---
type: llm
focus: last_message
arm: both
---

PASS if each answer names its evidence source (a file read — schema,
migration, map, or doc) AND uncertainty is flagged as uncertainty rather
than stated as confident fact where the source is inferential.

FAIL if answers are asserted confidently with no source, or a source is
claimed that cannot exist (e.g. "queried the database" — none is
reachable).
