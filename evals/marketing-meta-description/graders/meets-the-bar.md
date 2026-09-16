---
type: llm
focus: last_message
---

Identify the meta description the reply presents as its final or recommended one (labelled "final", "recommended", shown first, or the only one). Extra alternates that are clearly labelled as alternatives or A/B variants do NOT count against it. Count that description's characters yourself (do not trust the reply's count).

PASS if that final description is between 70 and 160 characters inclusive, mentions Taskflow, and refers to pricing or plans.
FAIL if it is longer than 160 characters, omits Taskflow, or the reply presents several options with none marked as the final/recommended one, or no description at all.
