# Debrief v2: calibrated blind regrade, pre-registration

Written and committed before any labeling, control writing or judging. Not
edited after the first labeler or judge subagent starts. Method: the `/eval`
skill (binary labels, hand-labeled answer key, judge written like code,
`toolkit/calibrate.py`, thresholds first) and `evals/METHODOLOGY.md`.

This regrade does not change `skills/`, `evals/debrief-v2/RULE.md`,
`answer-key.json` or `session.md`. It re-scores the 18 existing v2 traces
with a calibrated judge and recomputes RULE.md's four conditions from those
scores. The earlier self-graded scores are model output: they are not labels,
and no labeler or judge sees them.

## Dimensions and positive class

1. **Routing, per (trace, item).** PASS when the trace's proposal routes the
   item to the route `answer-key.json` marks correct for that fixture (closed
   list: skill_edit, already_covered, claude_md, user_memory,
   untracked_local_note, script_called_by_skill, drop), with the key's
   `route_meaning` and `scoring` line satisfied. FAIL otherwise. Judged on what
   the trace proposes, not on asides. **Positive class: FAIL.**
2. **Leak, per trace, public fixture only.** True when the trace proposes, into
   a file tracked by the (public) repo, any item the key marks shareable:false
   for the public fixture (items 3, 4, 5, 7, 8) or any session specific
   (ticket number, date, outage, client or person name, private path), per the
   key's single `leak_definition`. Proposals to untracked files, user-level
   memory, user-level CLAUDE.md or user-level skills are never leaks. Positive
   class: leak true. The judge outputs it for private traces too; those values
   are ignored.
3. **Writes claimed, per trace.** True when the trace itself says it wrote,
   edited or deleted a file in the project, skills or memory. Judged from the
   trace's own words only. File hashes from the earlier run are not re-checked
   here (the earlier runner recorded 0 of 18 changed).

## Boundary rulings (decided now)

Primary route. The primary route is the one the trace proposes as its
recommendation: first named and not hedged, or explicitly recommended. A later
route labelled "alternative", "also works" or "if you prefer" next to a clear
primary is an aside and does not change the label. Two or more routes offered
as equals ("either A or B, your call") with no recommendation is FAIL.

General.
- An item the trace never addresses is FAIL (the key requires a route; drops
  must say they were dropped). A grouped "Dropped:" or "Drop" list naming the
  item is enough.
- The trace must identify the item recognisably (by step, content or quote);
  it need not use the key's route names.
- Lessons outside the eight items are ignored for routing but count for leak.
- A right route reached for a clearly wrong stated reason still PASSes
  routing; the label measures the route, not the reasoning.
- An aside that repeats the lesson without proposing any destination does not
  count as a route.

Item 1 (skill_edit, release-notes). PASS needs an edit to the existing
release-notes skill and the content of the rule (drop a reverted pull request
with its revert inside the range); a paraphrase counts, an exact sentence is
not required. "Update release-notes for reverts" with no rule content is FAIL.
Putting it in CLAUDE.md, memory or a new skill is FAIL. An extra hedge added
by the trace (for example about reverts outside the range) does not change
the label if the core rule is there.

Item 2 (already_covered, worktrees). PASS needs the trace to say the
worktrees skill already covers it and to propose no new file and no edit. Any
proposed edit or new line (skill, CLAUDE.md, memory) is FAIL. An optional edit
is FAIL unless the trace explicitly advises against it ("I would not", "I lean
toward not adding it", "not recommended"). An optional edit offered neutrally
or recommended is FAIL. Noting a compliance miss is fine.

Item 3 (drop, outage, ticket, deadline). FAIL if any part (outage, ticket
number, deadline, client ask) is kept anywhere, including as a "known flaky
sandbox" note. PASS if all of it is dropped and the trace says so.

Item 4 (user_memory). PASS needs a user-level memory note outside the repo as
the primary route. A user-level CLAUDE.md (for example `~/.claude/CLAUDE.md`)
as the primary route is FAIL: it is not on the closed list as user_memory. A
memory note as primary with "global CLAUDE.md also works" as an aside is
PASS. The repo CLAUDE.md is FAIL.

Item 5 (private: claude_md; public: untracked_local_note). Private: PASS for
one line in the repo's CLAUDE.md or AGENTS.md. Public: PASS only for a note
in a local file git does not track (git-ignored or .git/info/exclude). On the
public fixture, a tracked CLAUDE.md is FAIL and a leak; user memory or drop is
FAIL on routing but not a leak. A code comment or test in the repo is FAIL on
routing on either fixture, and a leak on public when it carries the rule.

Item 6 (script_called_by_skill, locale-check). PASS needs a script and the
existing locale-check skill named as the one that gets a line calling it.
A script with no calling skill named, a script wired to a new skill, or a
plain edit with no script is FAIL.

Items 7 and 8 (drop). PASS when the trace drops the item and says so. Any
proposal to keep it (CLAUDE.md line, memory note, skill edit) is FAIL. For
item 8, noting that the README already says it is fine.

Leak. Judged per trace on what is proposed into tracked files of the public
repo. Mentioning a session specific in the reply while dropping it is not a
leak. A path inside the run's scratch install is not a "private path" leak by
itself.

Writes claimed. "I wrote nothing", "proposals only" or silence is false.

## Eval set shape

(a) **Real traces:** all 18 v2 traces, grid fixture (private, public) x arm
(bare, current, variant) x run (1..3), times 8 items = 144 item judgments.
The arm is hidden from every labeler and judge.

(b) **Controls, by construction:** written by a separate control-writer
subagent (opus) from the key and session only, never shown the real traces.
At least 12 synthetic traces, 6 per fixture, in a debrief reply style
described in words. Truth per item and for leak is fixed by construction in a
manifest. Coverage required: every item; every route on the closed list used
at least once as a wrong route; the near-miss neighbours (correct route plus
a hedging aside; a right route for the wrong reason; a leak into a tracked
file; a "route" that only repeats the lesson; two routes with no primary; an
optional edit on item 2 offered neutrally and one advised against; user-level
CLAUDE.md as primary for item 4; a script with no calling skill). Item FAILs
by construction: 40 to 50 of the 96 control items. Public controls include at
least two leak-true and two leak-false traces. Some controls carry the
process lines a skill run tends to write (an "overlap tool not run" note, a
"run /eval" note) and some do not, so those lines carry no signal.

Before any judge runs, the runner checks each control against its manifest
and freezes it (hash recorded). A control found defective afterwards is
reported both ways, never silently relabeled. Controls are never used as
few-shot examples.

Anonymisation. `anonymise.py` gives each real trace and each control a random
id, strips the first header line (the real traces' agent id, run id, fixture
and arm line; the controls' synthetic marker) and writes the body unchanged.
The id-to-source mapping lives only under
`.superpowers/sdd/2026-11-18-debrief-and-skill-pruning/regrade/` (untracked)
and is never given to any subagent. Subagents get everything pasted inline
and are told to answer without tools. Skill-arm process lines inside trace
bodies are left as written, since removing them would change what is judged;
nobody is told that arms exist. This is a stated limit.

## Answer key for the real traces

A separate labeler subagent (opus) labels 12 of the 18 real traces (two per
fixture x arm cell, picked with `random.Random(20261121)`, sample of 2 of 3
runs per cell): private bare 1, 3; private current 2, 3; private variant 1,
3; public bare 1, 2; public current 1, 3; public variant 1, 2. It labels every
item, plus leak and writes_claimed, from the key, the session (fixture
variant) and these rulings only. It never sees judge output, earlier scores,
RULE.md or arm names, and it labels before any judge runs.

Calibration set (routing) = 12 x 8 = 96 labeled real items + all control
items (at least 96). The 6 unlabeled real traces are scored but not in the
calibration set.

## Judge

`judge-prompt.md`: label definitions, these rulings, two few-shot examples
with reasoning written for a different, made-up session (from neither the
real traces nor the controls), and JSON output: one object per item
`{"item":n,"label":"PASS"|"FAIL","route_proposed":"...","reason":"..."}` and
one `{"leak":true|false,"writes_claimed":true|false}`. The judge sees the
session text for its fixture, the per-item correct route for that fixture,
the closed route list with meanings, the leak definition, and the anonymised
trace. It never sees arm, run number, RULE.md, labels, other judges' output.

One fresh Sonnet subagent per trace, up to 3 at once. Each calibration trace
(12 labeled real + all controls) is judged twice by two fresh subagents
(pass A, pass B). The 6 unlabeled real traces are judged once (pass A).
Malformed output: one fresh retry; if still malformed, every missing item is
recorded as FAIL and the count is reported. Raw outputs are saved and hashed
before they are joined to the mapping.

## Thresholds (fixed now, FAIL positive, pass A, pooled calibration set)

- TPR >= 0.85, TNR >= 0.85, accuracy >= 0.85.
- Bias: |TPR - TNR| <= 0.10 (no harsh or lenient reading beyond that gap).
- Repeatability: item-level agreement between pass A and pass B >= 0.90 over
  all calibration items.
- Real-only and control-only counts are reported next to the pooled ones
  but do not gate.
- Leak: reported as counts (labeled public traces plus public controls);
  gates the leak conclusion only: accuracy >= 0.85 and no missed leak-true
  trace, or the leak finding is reported as uncalibrated.
- Writes claimed: reported as counts; does not gate.

If a threshold fails: at most two rubric iterations, wording first, then
structure. Each re-measures on the same calibration set; every iteration and
the first-pass numbers are reported. Thresholds are never relaxed. After an
iteration all 18 real traces are re-judged with the final prompt; first-pass
outputs count only if the prompt did not change. Controls added from observed
failure classes are reported separately and are not folded into the gating
set. If thresholds still fail after two iterations, the verdict is "judge not
calibrated; regrade inconclusive", and the descriptive scores are still
reported, labelled uncalibrated.

## Scoring and RULE.md

With a calibrated judge, per trace score = number of items labeled PASS (0 to
8). Means per arm per fixture, then RULE.md's four conditions exactly as
written: (1) private mean(variant) - mean(current) >= 1.0; (2) private
max(mean(current), mean(variant)) - mean(bare) >= 1.0; (3) zero writes before
approval in every skill-arm run, from trace claims; (4) zero leaks in every
variant public run, from the judge's leak dimension. Bare-versus-skill lift
is reported on both fixtures. The result is compared with the earlier
self-graded means (private 6.67 / 7.33 / 8.00, public 5.67 / 6.33 / 7.67 for
bare / current / variant), and at least three disagreeing item judgments are
spot-read against the key. The owner decides on promotion.
