# Pre-registration: qa-full database and UI trigger decisions (2026-11-10)

Written before any run. Nothing below changes after results come in.

## Question

A Python/Jinja repo (schema.py, statements.py, HTML templates) matched none of
the old folder-name triggers, so `/qa-full` marked `/db-optimize` and `/qa`
NOT-TRIGGERED. This branch added `scripts/qa-triggers.sh` and told `/qa-full`
and `/daily-qa` to use it. Does an agent following the new text now call those
checks triggered on such a diff, and does it still say not-triggered on a
docs-only diff?

## Arms

- **before:** `git show origin/main:skills/qa-full/SKILL.md`.
- **after:** `skills/qa-full/SKILL.md` at HEAD (3f8da56).
- Each arm's text is copied to the scratchpad; the subagent reads that path.
- Subagent: in-session Sonnet `general-purpose`, at most five at a time. Free
  under the plan. `claude plugin eval` is not used.

## Scope of a run

Step 1 is done (feature branch, clean tree). The agent follows only the
trigger decision for the database check (Step 5) and the browser check
(Step 7) from its arm's text, invokes no sub-skill, fixes nothing, and writes
`decision.txt` in the fixture with exactly two lines:
`db: TRIGGERED|NOT-TRIGGERED` and `ui: TRIGGERED|NOT-TRIGGERED`.

## Cases (`evals/_lib/qa-full-trigger-fixture.sh <dir> <py|docs>`)

- **py (positive):** Python repo. The feature branch adds `app/db/schema.py`,
  `app/db/statements.py` and `app/templates/admin.html`. Right answer: both TRIGGERED.
- **docs (negative control):** same repo, the branch adds only `NOTES.md`.
  Right answer: both NOT-TRIGGERED.

n = 3 per arm per case, 12 runs.

## Pass rules (graded by `evals/_lib/qa-full-trigger-grade.sh`)

- A run passes when `decision.txt` has both lines and each matches the right answer.
- **H1:** after, py: 3/3 pass.
- **H2:** after, docs: 3/3 pass (no over-triggering).
- **H3:** before, py: reported as observed, no bar. It is the baseline that shows
  whether the old text missed.
- **H4:** the after-arm transcripts show `qa-triggers.sh` run for both kinds in
  at least 2 of 3 py runs. Reported, not a gate.

## Limits

The agent decides from a fixture, not a full pipeline run, so this tests the
trigger decision only. n=3 per cell is a pilot, not a proof. Agents are told
the superskills install is at `~/Sites/superskills` in both arms.

## Addendum (written after the first py results, before any hard or docs result)

The first five py runs (before 3/3, after 2/2 so far) all returned both TRIGGERED.
The py fixture holds a literal `SELECT ... FROM` line and a visible `<form>`, so a
hand judgment gets it right and the fixture cannot separate the arms. This is not
a change to H1 to H4; those stand as written. One more case is added:

- **hard:** the branch adds `app/db/schema.py` and `app/db/statements.py` with no
  SQL keywords, and `app/templates/report.html` that only displays text (no form).
  Right answer: both TRIGGERED (file names and a template page).
- **H5:** after, hard: 3/3 pass. before, hard: reported as observed, no bar.
  n = 3 per arm.
