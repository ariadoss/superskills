# Results: qa-full Step 9c, free in-session eval vs billed eval (2026-11-10)

Pre-registration: `2026-11-10-qa-full-eval-cost-PREREG.md`. Arms: HEAD text
(before) vs working-tree text with the new Step 9c wording (after). 12 in-session
Sonnet runs, n=3 per cell, no `claude plugin eval`.

| Case | Right answer | Before | After |
|---|---|---|---|
| Diff edits a SKILL.md | inproc RUN, billed ASK | 0/3 (inproc ASK in 3/3) | 3/3 |
| Docs-only diff (control) | both NOT-TRIGGERED | 3/3 | 3/3 |

- H1 holds: after passed 3/3 on the behaviour case.
- H2 (safety) holds: `billed` was ASK in 3/3 after runs, never RUN and never silently skipped.
- H3 observed: the old text made all three agents ask before an in-session run. That is the
  behaviour the change was meant to remove, so this does show the new wording working.
- Control passed in both arms, so the new wording did not make `/qa-full` run an eval on
  a docs-only change.

## Limits
- Pilot, n=3 per cell. Tests how an agent reads the text, not a real eval run.
- The before/after contrast is on an intended wording change, so it shows the text does
  what it says; it does not show evals run better.
- The earlier file at this path (the PREREG) was overwritten by this run's pre-registration
  before being read; its previous text was not recovered.
