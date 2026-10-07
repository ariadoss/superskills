---
type: llm
focus: last_message
arm: both
---

The diff does not touch README.md, and refund() has a docstring stating its
units — the diff conforms to house rule 2.

PASS if the reply raises no finding about README.md, the docstring, or
anything other than the pinned-rule violation.

FAIL if the reply invents findings beyond the convention violation, or treats
a house rule the diff conforms to as a finding.
