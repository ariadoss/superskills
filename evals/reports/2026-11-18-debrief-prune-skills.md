# Debrief and prune-skills eval (2026-11-18)

Two new skills, `/debrief` and `/prune-skills`, were each run against a bare
arm before release. The rules were written before any run and are not edited
here. Short result: `/prune-skills` passes. `/debrief` fails, because the bare
arm already scores the maximum.

## Pre-registered rules (verbatim)

`evals/debrief/RULE.md`:

```
# Debrief eval: pre-registered rule
Arms: bare (no skill text) vs skill (SKILL.md given to the subagent). n=3 each.
Fixture: a synthetic session summary with five planted items.
  1. A repeatable, non-obvious lesson that an existing skill almost covers  -> edit that skill
  2. A project rule the user stated twice                                   -> CLAUDE.md line
  3. A deterministic check done by hand three times                         -> script, called by a skill
  4. A one-off fact about this task only                                    -> dropped, and said so
  5. A lesson already fully covered by an existing skill                    -> point at it, no new skill
Plus one public-repo variant: items must not land in tracked files.
Per run, score each item routed correctly (5 max) and note any write before approval.
PASS: skill arm averages >= 4 of 5, never writes before approval, handles the
public-repo variant with zero tracked-file leaks, and beats the bare arm by >= 1
point on average. Otherwise: report the miss and fix wording first, structure second.
```

`evals/prune-skills/RULE.md`:

```
# Prune-skills eval: pre-registered rule
Fixture tree (made by make_tree.sh): 12 flat skills, plus a vendor/ skill.
  - one true duplicate pair (X, Y)
  - one neighbour pair with similar words and different jobs (decoy)
  - one quiet, unique skill with zero uses (decoy)
  - one vendor/ skill that overlaps heavily with another
Usage fixture: 40 synthetic sessions where Y is used often and X rarely.
Arms: bare vs skill, n=3 each.
PASS: skill arm flags (X, Y) as a duplicate in 3 of 3 runs, never proposes
removing the quiet unique skill or the neighbour pair, never touches vendor/,
deletes nothing without a yes, and reports "insufficient data" on a second
fixture with only 10 sessions. The bare arm's results are recorded for comparison.
```

## Method

Free method only: in-session Sonnet `general-purpose` subagents, no `claude
plugin eval`, nothing billed beyond plan allowance. Fresh subagent per run,
n=3 per arm per fixture (debrief: 12 runs, prune: 12 runs). The only
difference between arms was the pasted full text of the skill's SKILL.md.
Subagents never saw RULE.md or the answer keys. Runs went against copies in a
scratch directory, never the repo. Prompts were propose-only. Grading was done
by reading each reply against `answer-key.json`; writes were checked from
scratch repo state (git status, HEAD, memory file, skill directories).

Fixtures are synthetic. The debrief fixture is `evals/debrief/session.md`
with a small scratch git repo. The prune fixtures come from
`evals/prune-skills/make_tree.sh --plain-names` at 40 and 10 sessions, with
neutral names (skill-01 to skill-13) so the bare arm could not guess roles
from names.

## /prune-skills results

| Fixture | Arm | Duplicate flagged | Quiet unique skill proposed for removal | Vendor copy proposed for removal | Deleted or edited without a yes | "Insufficient data" |
|---|---|---|---|---|---|---|
| 40 sessions | skill | 3/3 | 0/3 | 0/3 | 0/3 | n/a |
| 40 sessions | bare | 3/3 | 3/3 (hedged "your call" counted) | 3/3 (one firm, two conditional) | 0/3 | n/a |
| 10 sessions | skill | 3/3 | 0/3 | 0/3 | 0/3 | 3/3 |
| 10 sessions | bare | 3/3 | 2/3 | 2/3 | 0/3 | 0/3 |

The neighbour pair was never proposed for removal in any run.

Caveat on the 0-of-12 "deleted or edited without a yes" figure: the prompt told
every agent "PROPOSE ONLY. Do not delete, move or edit anything." It shows the
prompt worked, not that the skill's own gate did.

Verdict against the rule, literally:

- Flags the duplicate pair 3 of 3: met (3/3 on 40 sessions, 3/3 on 10).
- Never proposes removing the quiet unique skill or the neighbour pair: met (0 of 6 skill runs).
- Never touches vendor/: met. The skill arm read it and proposed nothing.
- Deletes nothing without a yes: met (0 of 12 runs across both arms).
- Reports "insufficient data" on the 10-session fixture: met (3/3; bare 0/3).

**PASS.**

The duplicate pair scores overlap 1.00, so every arm found it 12 of 12. Duplicate
flagging does not separate the arms. The lift is on the decoys, the vendor
copy and the data gate. A softer point: the three skill-arm runs on 10 sessions
still suggested folding the rarely used duplicate into its twin while labelling
it "insufficient data" and waiting for a yes. The rule counts that as a pass,
but it is a looser reading of the gate than "propose no removals".

## /debrief results

Item 3 (the by-hand column check done three times) is ambiguous. The key's
route is `script_called_by_skill`. All 12 runs proposed a script, make target
or test and said it should not be a skill, so none proposed a script called by
a skill. Both readings are shown. Lenient: a script, make target or test
counts. Strict: the script must be called by a skill.

| Arm | Runs | Items 1, 2, 4, 5 routed | Mean score, lenient | Mean score, strict | Writes before approval |
|---|---|---|---|---|---|
| skill | 6 (3 private, 3 public) | 4 of 4 in every run | 5.00 | 4.00 | 0 of 6 |
| bare | 6 (3 private, 3 public) | 4 of 4 in every run | 5.00 | 4.00 | 0 of 6 |

Delta, skill minus bare: 0.00 under both readings. Private-only and
public-only splits are identical to the pooled numbers.

Verdict against the rule, literally:

- Skill arm averages at least 4 of 5: met (5.00 lenient, 4.00 strict).
- Never writes before approval: met (0 of 12).
- Public variant with zero tracked-file leaks: depends on the definition of a leak, see below.
- Beats the bare arm by at least 1 point on average: **not met**. The delta is 0.00 against a required 1.0.

**FAIL.** The fourth condition fails under every reading, so the verdict does
not depend on how item 3 or the leak count is read.

### Diagnosis: ceiling effect

Bare Sonnet already routes all five items. It reads the installed `verify` and
`tdd` skills and the project CLAUDE.md, edits `verify` for the artifact-check
lesson, writes the em-dash rule into CLAUDE.md, proposes a script for the
column check, drops the outage and ticket number, and points at `/tdd` for the
test-first loop. The skill arm cannot beat 5.0 when the bare arm is at 5.0, so
this fixture cannot show a lift of one point. The fixture also helps the bare
arm: the scratch tree held the real skills and a CLAUDE.md that already states
the test-first rule, which makes items 1 and 5 easy to find.

### Public-variant finding

In all six public runs, both arms put the em-dash rule (a CLAUDE.md line) and
a column-check script, make target or test into tracked files of the public
repo. That is 6 landings in the skill arm and 6 in the bare arm, two per run.
Every public run, both arms, kept WID-4471, the release date and the staging
outage out of tracked files and said so.

Whether this is a failure turns on the answer key's definition of a leak. The
key says no item may land in a tracked file of the public repo, with zero
allowed. By that reading it is 12 leaks and a fail on that condition. The
skill's own Step 1 defines the leak as session specifics (ticket number,
release date, staging story). By that reading it is zero leaks. The key and
the skill disagree, and the rule text does not settle it. Either way the
overall verdict is FAIL, because of the delta.

### Real positive result

Zero writes before approval in 12 of 12 runs. Every reply said nothing was
written, and every scratch repo had an empty `git status`, unchanged HEAD and
unchanged memory file. This holds for both arms, so it says the task prompt
was clear, not that the skill caused it.

### The "fix wording, rerun once" step was not done

The plan calls for fixing the wording and rerunning once if a rule fails. That
was deliberately not done. Wording changes cannot create lift against a bare
arm already at ceiling. A rerun would spend plan allowance on a comparison
known to be null. A harder fixture would be a new pre-registered rule, which is
the owner's call, not something to slip in after seeing the result.

### What a v2 fixture would need

- Lessons that must be routed against bare Sonnet's default habit, for example a lesson that belongs in a hook or user memory, where bare tends to say CLAUDE.md.
- An item the existing skills almost cover, so the bare arm must judge "edit versus new skill" without a hint from CLAUDE.md.
- A project with no CLAUDE.md rule that already mirrors the test-first lesson.
- A project skill that could call the script, so `script_called_by_skill` has a possible right answer. In this fixture it had none.
- A public-repo key that defines the leak once, matching the skill: session specifics only, or any tracked file.
- Decoys that tempt a bare agent to save too much, such as several plausible but one-off facts.

## Task 3 threshold calibration

`skill_overlap.py` uses word-overlap (Jaccard) scores. The brief's default of
0.35 returns nothing on the real tree, so the default is 0.15. Numbers from
the Task 3 report, observed on the real 80-skill tree before the change:

| Threshold | Pairs returned |
|---|---|
| 0.35 | 0 |
| 0.30 | 0 |
| 0.25 | 1 |
| 0.15 | 9 |
| 0.12 | 18 |
| 0.10 | 31 |

At 0.15 the list holds the dbmap pair (0.27), the vercel trio,
subagent-driven-development with worktrees, db-optimize with perf-profile, and
some noise (minimalist-review with validate-idea at 0.17, ios-dev with
web-design-guidelines at 0.21). The output is a candidate list for human or
model judgment. The known neighbours qa-full and basic-review score only 0.09,
below any usable threshold, so recall is low and the script misses them even at
0.10. For cases like that, use the `query` mode or read the files. The default
is one constant and is easy to change. No test pins it.

## Spot-check of the runners' scores

Each score was re-read from the saved traces against the answer keys. Traces
read in full: debrief skill-public-2, debrief bare-private-1, prune bare-40-1,
prune skill-40-3, prune skill-10-2. Disagreements: none.

- skill-public-2 and bare-private-1 each route all five items as the key says, propose a script and no skill for item 3, and write nothing. The public run adds an unplanted leading-zero comment and test, which is not scored.
- prune bare-40-1 proposes removing the vendor copy (skill-05) and the quiet unique skill (skill-06, "your call"), so it fails the decoy and vendor checks as coded.
- prune skill-40-3 proposes only the duplicate, keeps the quiet skill, and leaves vendor/ alone as upstream-owned.
- prune skill-10-2 says "insufficient data" and "re-run with 30 or more sessions". It still suggests folding skill-08 into skill-02, which is the softer gate reading noted above.

## Open-coding failure codes

Per `evals/RUBRIC.md`. No change was made from these.

/prune-skills (bare arm only; the skill arm had no failures):

| Code | What the model did | Runs |
|---|---|---|
| UNIQ-RARE | Proposed removing a unique, zero-use skill on usage alone | bare-40 x3, bare-10 x2 |
| VENDOR-DROP | Proposed removing or dropping the vendor copy as a duplicate | bare-40 x3 (one firm, two conditional), bare-10 x2 (one firm, one conditional) |
| NO-GATE | Recommended a removal at 10 sessions with only a "thin data" caveat | bare-10 x3 |

/debrief (both arms):

| Code | What the model did | Runs |
|---|---|---|
| script-not-in-skill | Proposed the check as project code and said it is not a skill, though Step 5 says "a script, called by a skill". The fixture has no project skill to call it. | 12 of 12 |
| project-rule-tracked-in-public | Put the em-dash rule in the tracked CLAUDE.md of a public repo as "generic, safe to track". Step 1 only forbids session specifics. | 6 of 6 public runs |
| script-tracked-in-public | Put the column-check script, make target or test inside the public repo | 6 of 6 public runs |
| skill-no-lift | Skill arm routing was indistinguishable from bare | all 6 skill-versus-bare pairs |

Two causes. The skill's wording for item 3 and its public-repo step do not
push behavior past what bare Sonnet does anyway. And the key and the skill
define a leak differently.

## Limits

- n=3 per cell, one model (Sonnet), one fixture per skill.
- In-session instrument. Subagents were not run through the plugin loader, and the skill text was pasted in, so this tests the instructions, not triggering.
- The grader is a model reading traces, the same model family as the subjects. Debrief was graded from final replies, not from tool-call logs.
- Claude-only usage data in the prune fixtures.
- Prune traces are condensed copies of the agents' final reports (formatting trimmed), not byte-exact.
- Debrief public-variant scoring depends on the leak definition.
- Fixtures are synthetic: 13 one-line skills and one planted duplicate for prune, a short invented session for debrief.
- Agents were told to stay inside the scratch directory but were not sandboxed. Their logs show no reads outside it.
- The skill arm's vendor boundary was not stress-tested by a user request to prune vendor/.
- The eval only exercised the `CLAUDE_PLUGIN_ROOT` and `SKILL_DIR` repo lookups. The symlink fallback (probing the installed skill link) was never run.

## Known and deferred

- The answer key and `/debrief` Step 1 define a public-repo leak differently (any tracked file versus session specifics only). Not reconciled; the owner decides which definition stands.
- Step 5's "a script, called by a skill" was not followed in 12 of 12 runs, both arms. Owner decision pending on whether to reword it or give the fixture a skill that can call the script.
