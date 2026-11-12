# Results: qa-full database and UI trigger decisions (2026-11-10)

Pre-registration: `2026-11-10-qa-full-triggers-PREREG.md` (written before any run;
the hard case was added in its addendum after the py results, before any docs or
hard result). Graded by `evals/_lib/qa-full-trigger-grade.sh`. Arms: `origin/main`
text of `skills/qa-full/SKILL.md` (before) vs HEAD 3f8da56 (after). In-session
Sonnet subagents, n=3 per cell, 18 runs, no `claude plugin eval`.

## Pass counts (a run passes when both db and ui are right)

| Case | Right answer | Before | After |
|---|---|---|---|
| py (literal SQL line and a form) | both TRIGGERED | 3/3 | 3/3 |
| hard (no SQL keywords, display-only template) | both TRIGGERED | 3/3 | 3/3 |
| docs (NOTES.md only) | both NOT-TRIGGERED | 3/3 | 3/3 |

All 18 passed, so H1, H2 and H5 hold. H3 (baseline, no bar): the old text did not miss.

## How each arm decided (H4)

- After arm: every py and hard run ran `qa-triggers.sh` for both kinds (6/6), and
  every docs run did too (3/3). H4 holds.
- Before arm: no script exists in that text. All nine runs judged by hand.
  The hard-case agents said they stretched the glob list ("query builders",
  "anything a human would QA") to get TRIGGERED, and one noted a strict literal
  reading would have said NOT-TRIGGERED.

## What this does and does not show

- The new text is not measurably better at the decision on these three fixtures:
  both arms were perfect. This pilot cannot show a benefit; with n=3 it also
  cannot rule out a small one.
- What changed is the method. The new text gets the answer from a script that is
  tested (910 bats tests), so it no longer depends on an agent choosing to read
  the prose generously. The old text got it right here only because Sonnet read
  the globs as examples.
- The bug seen on the original starforge run is therefore not reproduced by this
  fixture. A weaker model, a longer diff, or a diff where the SQL is in a changed
  non-SQL file with no obvious keyword might still separate the arms. Not tested.

## Observation

`scripts/qa-triggers.sh` prints "searched 0 changed file(s)" for a docs-only
diff, because the count is taken after ignored paths (docs) are dropped. The
verdict is right; the wording reads as if nothing changed. Informational.

## Judge calibration

No model judge was used. Grading is a deterministic parser of `decision.txt`, so
calibrate.py (judge vs human labels) does not apply.
