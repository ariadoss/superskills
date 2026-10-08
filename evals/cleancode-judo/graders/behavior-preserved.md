---
type: llm
focus: last_message
arm: both
---

The fixture's pytest suite pins behavior: every format round-trips its fields
and an unknown format raises ValueError.

PASS if the reply reports the suite green on the final HEAD (or, if no fix
was applied, reports the suite still green), and no behavior change is made
or claimed.

FAIL if fixes are claimed without a green-suite report, or a behavior change
is introduced (unknown format no longer raises, output contract broken).
