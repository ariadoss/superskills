# /qa-full context: pre-registration (2026-11-03)

Written and committed before any run. Not edited after the first run.

## Question
Where does a /qa-full run spend context, and does moving the three conditional
steps (5 database, 6 frontend perf, 7 browser QA) into on-demand reference files
cut context without changing what the pipeline does?

## Arms (same model, same prompt "Run /qa-full on this branch.")
- A: skills/qa-full/SKILL.md unchanged (record `git rev-parse HEAD` in results).
- B: Steps 5, 6, 7 moved verbatim to skills/qa-full/references/, each leaving a
  stub with its trigger text and a Read instruction in SKILL.md.
Fixtures: heavy = evals/_lib/qa-full-fixture.sh (triggers most checks);
light = evals/_lib/qa-full-light-fixture.sh (docs-only diff).

## Runner
In-session Sonnet general-purpose subagents, n=3 per arm per fixture (12 runs),
at most two active at once. All six A runs finish before any skill file is edited.
No claude plugin eval.

## Readings
Per run: `evals/_lib/qa-full-grade.sh` (invoked skills, unbacked ledger rows,
secret_absent, tests_green), `evals/_lib/transcript-context.py` (tool-result
bytes by tool, Skill and references), and `subagent_tokens` from the Agent result.

## Decision rule for the breakdown (A runs only)
Report the share of total tool-result bytes held by Skill results, Read results,
and everything else. If Skill-body results exceed 50% of bytes, record that the
bigger lever is running sub-skills in subagents with short handoffs, and open a
separate plan for it. That is not built here.

## Gates for adopting B (all must hold)
1. Behavior non-inferior, heavy fixture: in every B run, invoked skills include
   every skill that A invoked in at least 2 of 3 runs; unbacked = 0; secret_absent = 1;
   tests_green = 1 wherever A achieved it.
2. Behavior non-inferior, light fixture: same rule against A's light runs.
3. Mechanism works, light fixture: references_read = 0 in all three B runs
   (untriggered steps stay unread) and (mean total tool-result bytes of A) minus (mean of B) is at
   least 80% of the bytes moved into references/ (the three step files' combined size).
4. Mechanism works, heavy fixture: in every B run, each reference whose
   sub-skill A invoked in at least 2 of 3 runs was read before that sub-skill ran.

## Reported but never gated
subagent_tokens means per arm and fixture. n=3 cannot resolve effects under
about 15% (A's own runs have varied by about 10% either way).

## Outcome table
| Gates | Verdict |
|---|---|
| 1-4 hold | Adopt the split; ship at /ship time with a VERSION bump |
| 1 or 2 fails | Reject; the split lost a check |
| 3 or 4 fails, 1-2 hold | Reject as ineffective; document why |
| Any run truncated or errored | Report as such; do not impute |

n=3 is a pilot: a result is "signal" or "no signal at this scale".
