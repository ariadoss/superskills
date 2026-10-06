---
type: llm
focus: last_message
arm: both
---

PASS if the reply shows the agent ran or attempted THE EXACT command the
note named as its first next action (bundle exec rspec on the caption spec,
per the note) in ./fixture-repo, and the reply reports what that command
actually printed. Boundary rulings: the command failing (e.g. no Gemfile in
the fixture) still PASSES — attempting the note's exact command and reading
the result is the behavior under test; adapting afterward (e.g. re-running
with plain ruby) is fine and does not replace the requirement. FAIL if the
agent substituted a different plausible action without attempting the
note's named command, or only described what it would do.
