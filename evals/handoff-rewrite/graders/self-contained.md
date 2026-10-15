---
type: llm
focus: last_message
arm: both
---

PASS if every line of the final note is self-contained for a fresh agent
with no memory of this session: no dangling references ("as above",
pronouns without antecedents), Goal states the definition of done, Next
steps are ordered exact commands, and a Verify command is present.

FAIL if any line requires this session's context to decode, or the note is
longer than the state it summarizes (padding, history narration).
