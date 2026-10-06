---
type: llm
focus: last_message
arm: both
---

PASS if the reply shows the agent executed THE NOTE'S OWN first next step,
exactly as the note states it, in ./fixture-repo — whatever that step is
(read the note's Next steps section: commonly an inspection command such as
git status / git diff on the in-flight files, sometimes the test command) —
and reports what the command actually printed. Boundary rulings: the
command failing (e.g. no Gemfile for bundle exec rspec) still PASSES;
stopping after the first step and reporting is correct (the prompt asks for
the single next action). FAIL if the agent substituted its own plan without
executing the note's stated first step, or only described what it would do.
