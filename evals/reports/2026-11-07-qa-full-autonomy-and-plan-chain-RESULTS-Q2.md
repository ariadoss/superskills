# Results: Question 2, /write-plan review handoff (2026-11-07)

Pilot, n=1 control and n=2 per other arm, per plan. Two plans: a Rails starred-items
feature ("crud") and a bash backup.sh redesign ("strat"). Sonnet subagents, no human,
no paid calls. Numbers come from the agents' own reports; plan diffs were not
re-audited line by line.

## Subagent tokens

| Arm | crud | strat |
|---|---|---|
| A: today's text (/plan-eng-review) | 103k | 96.5k |
| B: /autoplan | 86k, 109k | 167k, 104k |
| C: eng methodology only | 91k, 143k | 113k, 140k |

## What happened

- A: `/plan-eng-review` returned "Unknown skill" in both runs. Both agents fell back
  to reading gstack's plan-eng-review/SKILL.md by hand and still found real bugs
  (13 on crud including a race bug; 6 on strat). So H1 passed 2/2, but only through
  an improvised fallback after an error. The pre-registered "moot if A passes 4/4"
  clause does not apply: n was 2, not 4.
- B: no run was the full pipeline. The Claude-subagent voice was refused by the
  concurrent-subagent limit in all four runs and Codex was unavailable, so every
  /autoplan run was one reviewer doing all phases inline, with no snapshot/phase-close
  steps. CEO changed nothing in the crud runs; DX changed nothing. The DX scope check
  fired on words like "flag", "API", "command" in both plans (a false positive twice).
- C: both phases scoped to engineering; found the same headline bugs as B and A.
  Two strat runs and one crud run probed real behavior (macOS rsync) before editing.

## Pre-registered grades

- H1 (review ran): A 2/2 (via fallback), B 4/4, C 4/4.
- H2 (Test Plan Artifact written): checked on disk (~/.gstack/projects/). A 2/2,
  B 0/4, C 0/4. An earlier draft of this report wrongly said some C runs wrote one.
  A's runs were not a valid control for the skill (the command returned "Unknown
  skill" and the agents improvised). Both B and C agents ran loosely and skipped
  the step; autoplan's own eng-phase.md requires it ("NEVER SKIP OR COMPRESS"), so
  the gap is in how the agents ran it, not in what the skill says.
- Consequence: Q2 is not decided by this pilot. A fair rerun needs the vendored
  plan-eng-review (vendor/gstack 1.91.2.0, pre-retirement) vs /autoplan, each run
  as written, with an on-disk test-plan check.
- H3 (edits confined to test/task sections): no run reported a product-scope
  rewrite; not diff-verified.
- H4 (questions asked): not measurable, no human.
- H5 (tokens): B pooled mean about 116k over four runs; C about 122k over four
  runs (91k, 143k, 113k, 140k). B is within 1.5x C, and cheaper.

## Decision under the pre-registered rule

Withdrawn. H2 failed for both B and C (0/4 each), and A was not a valid control,
so the earlier "default to C" call is not supported. Open until the fair rerun.

Caveat: quality across arms was close. All arms caught the same headline bugs
(vacuous race test, wrong 0700 check, broken fleet check). The main separators are
that A depends on a command that no longer exists, and B adds phases that changed
nothing here and a DX trigger that misfires.
