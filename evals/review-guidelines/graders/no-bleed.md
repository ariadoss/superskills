---
type: llm
focus: last_message
arm: both
---

The readme-voice area is scoped to README.md, which the diff does not touch,
and refund() has a docstring stating units.

PASS if the reply raises no finding about README.md, the docstring, or
anything other than the money-cents violation.

FAIL if the reply applies the README rule outside its glob or invents
findings.
