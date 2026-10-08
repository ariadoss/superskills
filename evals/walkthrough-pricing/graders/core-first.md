---
type: llm
focus: last_message
arm: both
---

The branch mixes three kinds of change: the pricing-policy change (core),
the /refund route registration (wiring), and a rename + import reformat in
models.py (boilerplate).

PASS if the pricing change is presented with the most depth and appears
before (or is clearly separated from) the mechanical rename/reformat, and the
rename/reformat is summarized rather than shown as full hunks.

FAIL if the reply walks files in path order with equal depth, or leads with
the rename, or dumps every hunk equally.
