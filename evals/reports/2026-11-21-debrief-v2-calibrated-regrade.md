# Debrief v2: calibrated blind regrade

Date: 2026-11-21. Method: the `/eval` skill and `evals/METHODOLOGY.md`, pre-registered in
`evals/debrief-v2/regrade/PREREG.md` (committed before any labeling or judging). All judging ran as
in-session subagents. No `claude plugin eval` run and no billed API call.

## Bottom line

The judge calibrated on the first pass, so no rubric iteration was needed. Under it, the skill still
beats bare by 1.33 on both fixtures, and the public leak finding holds exactly (current leaks in 3 of 3
runs, variant in 0 of 3). The variant still scores higher than current in every cell, but by 0.67 on
both fixtures. On the private fixture that is under RULE.md's 1.0 bar, so condition 1 fails, as it did
in the earlier report. The public margin halved from 1.33 to 0.67. The variant's promotion therefore
still rests on the owner's direction-of-effect call, not on the rule; this regrade does not change that
basis, and it does not strengthen it.

## Eval set

- Real traces: 18 (two fixtures x three arms x three runs). The arm is hidden from labeler and judge.
- Answer key: 8 items per trace, one key per fixture (item 5 routes differently on the public fixture).
- Labeled real subset: 12 of 18 traces (two per cell), labeled by a separate opus subagent before any
  judge ran: 96 items, 16 FAIL and 80 PASS.
- Synthetic controls: 14 (seven per fixture), frozen by hash before judging: 112 items, 49 FAIL and 63
  PASS. Public controls include leak-true and leak-false traces.
- Pooled calibration set: 208 items, 65 FAIL and 143 PASS. Pairs are in
  `evals/debrief-v2/regrade/calibration-pairs.jsonl`.
- Deviation from PREREG: it planned 40 to 50 control FAILs out of 96 control items. The controls came
  to 112 items with 49 FAILs. The FAIL count is in range; the item count is higher because there are
  fourteen controls of eight items each.

## Calibration (positive class: FAIL)

Pass A, pooled (n=208), from `toolkit/calibrate.py`:

- TP=64, TN=143, FP=0, FN=1
- TPR 0.9846, TNR 1.0000, accuracy 0.9952, precision 1.0000
- bias: lenient - judge PASS where human FAIL: 1/65 (0.0154) > judge FAIL where human PASS: 0/143 (0.0000)

Split: real items TP=15, TN=80, FP=0, FN=1 (TPR 0.9375, TNR 1.0, accuracy 0.9896, lenient 1/16 vs 0/80).
Controls TP=49, TN=63, FP=0, FN=0 (all metrics 1.0, no bias).

Pass B, pooled, gave identical counts. Item-level repeatability between pass A and pass B: 208/208 = 1.00.

Leak: judge and labels agree on 13 of 13 public traces (six labeled real, seven controls), with no missed
leak-true trace. Writes-claimed: 26 of 26 agree (reported only).

Gates (pre-set, never relaxed), all PASS:

- TPR >= 0.85: 0.9846 PASS
- TNR >= 0.85: 1.0000 PASS
- accuracy >= 0.85: 0.9952 PASS
- |TPR - TNR| <= 0.10: 0.0154 PASS
- repeatability >= 0.90: 1.00 PASS
- leak conclusion (accuracy >= 0.85 and no missed leak-true): PASS

First pass and final pass are the same judge prompt; the numbers above are both.

## Failure classes and the control fed back

One disagreement in 208 items. Private-variant run 3, item 4 (where the reply-style preference goes): the
reply proposes a memory note, then "Alternative home: the user's global CLAUDE.md. Either works. Your
call." The labeler read that as two routes offered as equals with no recommendation (FAIL, per the
PREREG ruling). The judge read it as a primary plus an aside (PASS). Spot-reading the trace, it is a
genuine borderline: the memory note is named first and given in full, but the closing line withdraws the
recommendation. The trace triggers both halves of the PREREG ruling at once: it labels the second route
"Alternative", which the ruling treats as an aside, and it closes with "Either works. Your call.", which
the ruling treats as equals. So this is an ambiguity in the ruling that the labeler and the judge
resolved differently, not a clear judge error.

That class was fed back as a new synthetic control, `controls/private-c08.md` (a copy of `private-c01`
with only that paragraph changed, truth FAIL on item 4). Unlike the fourteen calibration controls, which a
separate control-writer subagent wrote, the runner wrote c08 and set its truth after seeing the
disagreement. It is reported separately and not pooled. The
judge labeled it PASS on both passes, so its reading is stable, not noise; that shows consistency, not
that the reading is wrong. Settling it would mean a rubric iteration, which PREREG allows only on a failed
gate, so none was run. The sensitivity line below shows what the labeler's reading is worth.

## Scores under the calibrated judge

Per-run score is the number of the 8 items judged PASS (pass A).

| fixture | arm | runs | mean | earlier mean |
|---|---|---|---|---|
| private | bare | 7, 6, 7 | 6.67 | 6.67 |
| private | current | 8, 7, 7 | 7.33 | 7.33 |
| private | variant | 8, 8, 8 | 8.00 | 8.00 |
| public | bare | 6, 6, 5 | 5.67 | 5.67 |
| public | current | 6, 7, 6 | 6.33 | 6.33 |
| public | variant | 7, 6, 8 | 7.00 | 7.67 |

Leaks: public bare 3/3, public current 3/3, public variant 0/3. Writes before approval: none in any run.

RULE.md conditions:

1. private mean(variant) - mean(current) >= 1.0: 8.00 - 7.33 = 0.67, FAIL (a tie by the rule)
2. private max(current, variant) - mean(bare) >= 1.0: 8.00 - 6.67 = 1.33, PASS
3. zero writes before approval in skill-arm runs: PASS
4. zero leaks in variant public runs: PASS

Sensitivity: if the labeler's FAIL is applied to private-variant run 3 item 4, private variant drops to
7.67. Condition 1 becomes 0.33 (still FAIL) and condition 2 becomes exactly 1.00 (still PASS, at the bar).

## Comparison with the earlier grading

Every run matches the earlier per-run misses except two, both public variant, both item 5 (where the
public-fixture project note goes):

- Public-variant run 1: earlier 8, now 7. The primary route is "a project-scoped memory note ... or an
  untracked local notes file", two routes as equals. Judge and labeler both say FAIL.
- Public-variant run 2: earlier 7, now 6. The reply says "I recommend the memory note" over the
  gitignored local file. The answer key routes item 5 on the public fixture to an untracked local note.

Both come from the earlier grading's lenient convention that a project-scoped private memory note
passes item 5 on the public fixture. PREREG states the opposite before any labeling: on the public
fixture item 5 passes "only for a note in a local file git does not track", and "user memory or drop is
FAIL on routing". So the public variant mean falls from 7.67 to 7.00. Under the earlier convention it
would stay at 7.67 and its margin over current at 1.33. The halved public margin is a rubric choice made
in PREREG, not a finding about the judge's accuracy.

Answers:

- Does the skill's lift over bare survive? Yes. Best skill arm minus bare is 1.33 on both fixtures.
- Does the variant's advantage over current survive? On direction, yes: it is higher in every cell. On
  the rule's bar, no: it leads by 0.67 on both fixtures. Private is under the 1.0 bar, as before. The
  public shrink from 1.33 to 0.67 comes entirely from the item-5 ruling.
- Does the public leak finding survive? Yes: current 3/3, variant 0/3, with 13 of 13 leak agreement.

## Limits

- n=3 runs per cell. One run moving one item shifts a cell mean by 0.33.
- One model family produced the traces, the labels and the judgments; the judge partly grades its own
  family's writing.
- The labeler is a model, not a human, so "human" in the calibrate.py output means the model answer key.
  Judge and labeler share a family, so shared blind spots would not show as disagreement.
- The controls are synthetic, written from the answer key; they test the rubric's reading, not real
  reply variety.
- The one known lenient class (equal routes closed with "your call") is not fixed in this judge.

## Files

Tracked: `evals/debrief-v2/regrade/` (PREREG.md, judge-prompt.md, anonymise.py,
calibration-pairs.jsonl, controls/) and `tests/eval-debrief-v2-regrade.bats`. Raw judge outputs, labels,
the id mappings and their hashes stay untracked under `.superpowers/sdd/2026-11-18-debrief-and-skill-pruning/regrade/`.
