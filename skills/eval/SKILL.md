---
name: eval
description: |
  Measure whether a change to AI behavior actually improved things, the way a
  code change is measured: binary quality dimensions, a grid-sampled synthetic
  eval set with negative controls and a generated response side, a hand-labeled
  answer key, a judge written like code, then judge calibration with
  toolkit/calibrate.py (TP/TN/FP/FN counts, TPR, TNR, accuracy, precision, and
  a harsh/lenient bias reading) before gating on thresholds set before the run.
  Use when the user changed AI behavior (prompt wording, a skill description or
  body, an agent loop, a RAG pipeline) and needs to know whether it helped, or
  asks to "build an eval set", "calibrate a judge", or "evaluate the prompt".
  Not the harness command `claude plugin eval`, and not a substitute for
  ordinary code tests: those check deterministic code, this measures judgment
  behavior.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
---

# Eval: measure AI behavior changes like code changes

A change to AI behavior (prompt wording, a skill's description or body, an
agent loop, a RAG pipeline) is a code change with no compiler: without a
measurement you cannot tell help from harm, and neither can a reviewer. This
skill runs the loop **Generate, Run, Evaluate, Analyze, Improve**, repeated:
evaluation is a cycle, not an event, and the goal is steady visible movement,
not a perfect score in one pass. Measure **before** changing anything, or you
cannot confirm the change helped.

The toolkit does the arithmetic. **You, the agent, make the judgment calls**:
which dimensions matter, which grid cells to sample, what each label means,
where the rubric wobbles, and whether a failure is a wording bug or a
structure bug. Those calls are the skill; the script only keeps the numbers
honest.

`TOOLKIT` below means the `toolkit/` directory inside this skill's own
directory. The host prints that directory when the skill loads (Claude Code:
"Base directory for this skill: …"); use it. Do **not** derive it from `$0`:
in your shell that names the shell, not this file. Confirm the path before
running anything, so a wrong one fails loudly instead of phase 5 running
nothing:

```bash
TOOLKIT="<base directory for this skill>/toolkit"
# Fallback, only if the host printed no base directory. Never the shell's cwd:
# that would run whatever toolkit/ happens to sit there.
for d in "$TOOLKIT" "$HOME/.claude/skills/eval/toolkit"; do
  [ -f "$d/calibrate.py" ] && { TOOLKIT="$d"; break; }
done
[ -f "$TOOLKIT/calibrate.py" ] || { echo "eval toolkit not found" >&2; exit 1; }
```

## Prerequisites

Python 3, standard library only. Nothing to install. The toolkit never calls
a model: judging is the judge prompt's job, calibration is pure arithmetic.

## Phases

**1. Define "good" as binary dimensions.**

Pick the dimensions the change is supposed to move (selection, safety,
correctness, outcome) or the project's own, and define each one as a binary
label: pass/fail, resolved/not-resolved. Graded scales multiply the
disagreement surface before you can even measure it, so stay binary until the
taxonomy is stable. Decide, in writing, which label is the **positive**
class for reporting; FAIL is the usual choice when judging quality, because a
false positive then means "the judge failed a run the human passed", which is
the harsh direction. State the positive class next to every number you
report: swapping it swaps TPR and TNR and changes what precision means.

**2. Build the eval set on a declared grid, not at random.**

Asking a model for "100 random questions" produces repetitive, obvious cases
clustered around the easy middle. Sample on a deliberate grid instead:

- **intent × persona × complexity**: every cell that makes sense gets cases;
- **negative controls are part of the plan**, not an afterthought: requests
  that should *not* trigger the behavior, including near-miss neighbors;
- **edge cases on purpose**: ambiguity, misspellings, multi-turn context,
  adversarial inputs. Testing only typical inputs means production failures
  are discovered by users first;
- **mix synthetic and real traffic** where you have real traffic; synthetic
  data speeds iteration but must reflect the real distribution.

Generate the **response side too**: for each case, produce responses of each
kind (complete, partial, workaround, escalation, vague/incorrect) so the
judge is tested on every grade, not just the easy passes. Decide up front how
workarounds, escalations and partial answers map onto the binary labels; a
binary judge does not need a label per response type.

Two hygiene rules. Keep eval data unseen: never reuse evaluation cases as
few-shot examples in the thing being graded, that is data leakage. And one
observed failure is a class: when a case fails, generate more cases like it
and fix the class, never a hard-coded fix for the one case you saw. Check the
generated set before trusting it (quality, diversity, realism, coverage
gaps); a judge calibrated on a narrow set is only calibrated for that narrow
set.

**3. Hand-label a representative subset: the answer key.**

Label a representative subset of runs by hand. This subset is the ground
truth every judge metric is computed against, so it must span the grid,
including the awkward cells. Keep the labels binary per phase 1. After the
judge runs, the calibration file is one pair per line, human first:

```json
{"human": "FAIL", "judge": "PASS"}
```

**4. Write the judge like code.**

The judge is a prompt with a job description, and it is writable, testable
and improvable exactly like code:

1. **Exact label definitions.** What counts as pass? Does pass require a
   complete fix, a workaround, or a correct escalation?
2. **Boundary cases decided in advance**: the accurate-but-jargon-heavy
   answer, the correct redirect of an out-of-scope request, the partial
   resolution that needs one more user reply. Write the ruling into the
   rubric before running, not after seeing the judge wobble.
3. **Few-shot examples with reasoning**: a positive, a negative, and *why*
   each is what it is. The reasoning is the part that transfers.
4. **Low temperature (≤ 0.2)** so judgments repeat.
5. **Structured output**: JSON with a label and a one-line reason, so grading
   is a parser, not a string hunt.

```text
You grade whether the response resolved the user's issue.
Label definitions: PASS means ...; FAIL means ...
Boundary cases: a correct workaround is PASS; an accurate but jargon-heavy
answer is PASS; an out-of-scope request correctly redirected is PASS; ...

Example 1 (PASS, with reasoning): ...
Example 2 (FAIL, with reasoning): ...

User issue: {case}
Response: {response}
Answer with JSON only: {"label": "PASS"|"FAIL", "reason": "..."}
```

**5. Calibrate the judge with the toolkit.**

Before trusting the judge at scale, measure the judge itself against the
answer key. Run the judge over the labeled subset, write the human/judge
pairs to a file (a two-column CSV, human first, also reads), then:

```bash
python3 "$TOOLKIT/calibrate.py" labels.jsonl                  # FAIL positive, the usual
python3 "$TOOLKIT/calibrate.py" labels.jsonl --positive PASS  # the swapped convention
```

You get the confusion counts (TP/TN/FP/FN), TPR (recall), TNR
(specificity), accuracy, precision, all at 4 decimals, and a one-line bias
reading: harsh when the judge fails good work more than it waves bad work
through, lenient when the reverse, computed from the two error rates for the
positive class you declared.

Sanity anchor, the method's worked example. 80 human-labeled runs, 50 FAIL
and 30 PASS; the judge fails 44 of the 50 and passes 21 of the 30. Then
TP=44 TN=21 FP=9 FN=6, TPR 0.8800, TNR 0.7000, accuracy 0.8125, precision
0.8302, and the reading is harsh: wrongly failed 9/30 (0.3000) versus waved
through 6/50 (0.1200). Run the same input through the tool once when you set
up; if your numbers disagree with this anchor, the input or the tool is
wrong, not the method.

How to read the output:

- **Report TPR, TNR, accuracy and precision together, never accuracy
  alone.** Accuracy is blind to error direction: 85% correct could be a
  judge that fails good work or one that waves bad work through.
- **A wide TPR-TNR gap is directional bias.** Name the direction from the
  error rates, not a hunch: the wrongly-failed share versus the waved-through
  share. The bias line does this for the declared positive class; declaring
  the other class swaps TPR and TNR but must not flip the verdict.
- **At small n the counts are the signal.** TPR 0.88 over 50 labeled runs is
  a measurement; over 6 it is noise dressed up as a percentage.
- **Every disagreement is a rubric bug before it is a model bug.** Sharpen
  the label definitions, add a few-shot aimed at the direction it errs in,
  re-judge, re-measure. Do not ship a judge whose TPR and TNR disagree
  widely.

**6. Gate and iterate, thresholds first.**

Set pass thresholds **before** looking at results (choosing them after is how
A/B tests lie), keep a rollback path, and feed observed failures back as new
eval cases. The suite grows toward the stopping rule: add cases until new
traces stop producing new failure modes.

Keep two dashboards separate. **Judge metrics** (phase 5) measure the judge
against humans; a judge can agree perfectly with humans about a system that
is failing. **System metrics** measure the thing you shipped: pass rate per
dimension, failure rate per category, percent resolved per issue type, plus
business outcomes (execution rate, escalation rate, latency). Compute system
metrics per category while iterating, not only globally; an aggregate can
hold still while a category burns. For agents, judge outcome plus process
sanity, never step sequences: different valid paths reach the same answer, so
grade decision quality and final-output correctness, with budgets (max steps,
cost, timeout) and tool-error counts in the report. For RAG, retrieval
metrics are leading indicators (Recall@k, Precision@k, MRR) before touching
generation; fix retrieval first, a faithful generator over a broken retriever
still fails.

When a gate fails, fix **wording before structure**: sharper label
definitions, a better few-shot, a clearer boundary ruling. Change structure
only if the measured category rate does not move after the wording fix.

## Report

End with evidence, not a verdict word: the eval-set shape (grid cells,
negative controls, counts), the answer-key size, the judge's four metrics
with the positive class named, the bias reading with counts, the thresholds
that were set beforehand, and which gates passed or failed. Name the top
failure classes observed and what was fed back as new cases.

## Never

- Never report accuracy alone.
- Never set or adjust thresholds after seeing the results.
- Never reuse eval cases as few-shot examples in the thing being graded.
- Never hard-code a fix for the one case you saw; one observed failure is a
  class.
- Never let the judge see the human label, and never let the judge's own past
  output stand in for the answer key.

## Further reading

`evals/METHODOLOGY.md` in the superskills repo is the long-form method this
skill operationalizes; that path does not exist inside a standalone export of
this skill, which is why this file is self-contained.
