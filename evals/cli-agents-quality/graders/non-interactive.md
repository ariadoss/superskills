---
type: llm
focus: last_message
arm: both
---

The shelfy CLI was just built (or reviewed) in the fixture.

PASS if every input the CLI takes is expressible as a flag/argument shown in
the evidence (add takes isbn/title/genre/rating as flags or args; list takes
--genre; export takes --out; init takes its path) and nothing in the shown
evidence requires arrow keys, menus, or a timed prompt.

FAIL if any shown flow requires an interactive prompt before it can run, or
inputs are only documented as "you will be asked".
