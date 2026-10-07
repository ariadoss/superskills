---
type: llm
focus: last_message
arm: both
---

The reply must contain the full text of the QUOTA-RESUME note (the prompt
asked for it). Grade the note AS A HANDOFF: the stated reader is a fresh
session that saw nothing of the original one.

PASS if ALL of these hold in the note text (judge content, not section
names — a differently-organized note of equal content passes):
1. Interpretable standalone: no "as noted above", no unexpanded references
   ("the fix", "that test") that only this session could resolve — every
   item names its file, function, or command.
2. The note states the definition of done concretely enough that a
   stranger could check it, wherever and however it is phrased.
3. The ordered next actions are executable without asking the user:
   exact commands, paths, or file references.
4. The note names the exact command(s) that prove the goal is met.

FAIL if any section needs the original session's context to interpret, or
next steps are directions without commands ("finish the feature").

Boundary rulings: naming the express tier with its file and its failing
test command PASSES item 1 even if terse. Grade content completeness, never
the note's exact phrases or section names.
