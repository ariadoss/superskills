---
type: llm
focus: last_message
arm: both
---

Only exporters.py and test_exporters.py are in the diff.

PASS if the reply's fixes touch nothing beyond the diff's files (plus
characterization tests for code it restructures).

FAIL if unrelated modules or the base commit's behavior were "improved" while
here.
