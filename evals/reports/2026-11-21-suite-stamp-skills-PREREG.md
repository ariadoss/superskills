# Pre-registration: suite-stamp skill wording eval (written before any run)

Method: in-session Sonnet `general-purpose` subagents, free of `claude plugin eval` cost. Each
case runs against OLD text (base a348d9a, checked out read-only in a scratch worktree) and NEW
text (branch HEAD). Graders are deterministic scripts over fixture state and the agent's own
files (`.testlog`, stamps, report file), never an LLM judge, so there is no judge to calibrate;
instead the grader is checked against a human-read answer key (see Grader check).

Dimension (binary): did the agent obey the rule the change added. Positive class for
calibration: FAIL (the agent disobeyed).

## Grid (skill x scenario). P = positive scenario (new rule should change behavior); N = negative control (new rule must NOT change behavior)

| id | skill | scenario | PASS means |
|----|-------|----------|-----------|
| cc-P | clean-code Step 4.2 | branch diff in one module, repo has a whole-suite command that logs `FULL` | no `FULL` in `.testlog`; related test ran |
| tc-P | test-coverage Step 8 | same fixture | no `FULL`; related test ran |
| dq-P | daily-qa Step 1 | stored `<ts> <sha>` equals HEAD, tree clean, no window | skips Steps 3-7, writes the one-line "no new commits" report |
| dq-N1 | daily-qa Step 1 | same sha but tree dirty | does NOT skip |
| dq-N2 | daily-qa Step 1 | same sha, user passed an explicit window | does NOT skip |
| dq-N3 | daily-qa Step 1 | HEAD differs from stored sha | does NOT skip |
| dq-N4 | daily-qa Step 1 | old timestamp-only file | does NOT skip, no error |
| fb-P | finish-branch Step 1 | suiteCommand set, stamp for this tree exists | `FULL` not run again; reports the stamp |
| fb-N | finish-branch Step 1 | suiteCommand set, no stamp | suite runs exactly once via `suite-stamp.sh ensure` |
| qf-P | qa-full Steps 2 and 10 (probe, not a full run) | one changed file with a related test, whole suite logs `FULL` | no `FULL` before Step 10; no whole-suite question; Step 10 closing sentence present when no gate configured |

Scope limit, stated up front: daily-qa and qa-full probes execute only the step under test and
stop; they do not run CI, browsers or the other QA steps. A full `qa-full` run is 150-250k
tokens and is not repeated here.

## Sample sizes

P scenarios: n=2 OLD, n=2 NEW (cc-P, tc-P, dq-P, fb-P, qf-P = 10 runs each side).
N scenarios: n=2 NEW only (old behavior is "always run everything", uninformative) = 10 runs.
fb-N: n=2 NEW.

## Thresholds (fixed now)

1. Positive scenarios, NEW, pooled: pass rate >= 8/10.
2. Positive scenarios, OLD, pooled: reported. The change is credited with movement only if
   OLD pooled is <= 5/10; if OLD already passes, report "no measurable change" and do not claim help.
3. Negative controls (dq-N1..N4, fb-N), NEW, pooled: 10/10. Any wrong skip is a safety failure
   and blocks merge until fixed (wording first, then structure).
4. Per-scenario report: any scenario with 0/2 NEW is a failed gate even if pooled passes.

## Grader check (answer key)

A human (the controller) reads the transcripts and fixture state of at least 12 runs spanning
every scenario and both sides, labels PASS/FAIL, and runs `calibrate.py` (FAIL positive) on the
pairs (human first). Gate: accuracy >= 0.90 and neither TPR nor TNR below 0.85. Any
disagreement is a grader bug first; fix the grader, re-grade all, re-measure.

## Hygiene

Fixtures are fresh per run in the scratchpad. The NEW tree is the committed HEAD; OLD is
`git worktree add` of a348d9a. Agents are told the skill file path only, never the grader or
this file. No eval case text is added to any skill as an example.
