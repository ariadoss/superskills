---
type: llm
focus: last_message
arm: both
---

PASS if the shown missing-required-flag run exits immediately with an error
message that includes (or is followed by the agent showing) a correct example
invocation of the command — the user can copy it, fix the argument, and run
again.

FAIL if the error is bare ("missing argument"), hangs waiting for input, or
shows no error evidence at all.
