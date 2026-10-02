# Running an evaluation with synthetic data

How to test an AI behavior change (a prompt edit, a skill rewording, an
agent-loop change, a RAG pipeline tweak) the way you would test a code
change. "It looks better" is not evidence: without an evaluation you cannot
tell help from harm, and neither can a reviewer. This page is the general
method; [`RUBRIC.md`](RUBRIC.md) is this repo's working instance of it,
[the workflow guide](../DEVELOPER_WORKFLOW.md#evaluate-ai-behavior-changes-like-code-changes)
says when to reach for it, and the `/eval` skill (`skills/eval/`) is the
runnable form: its `toolkit/calibrate.py` computes everything below from a
file of human-vs-judge label pairs.

The loop, once built: **Generate → Run → Evaluate → Analyze → Improve →
repeat.** Evaluation is a cycle, not an event. The goal is steady, visible
movement, not a perfect score in one pass. Measure *before* changing
anything, or you cannot confirm the change helped.

## 1. Build the eval set on a grid, not at random

Asking a model for "100 random questions" produces repetitive, obvious cases
clustered around the easy middle. Sample on a deliberate grid instead:

- **intent × persona × complexity**: every cell that makes sense gets cases;
- **negative controls are part of the plan**, not an afterthought: requests
  that should *not* trigger the behavior, including near-miss neighbors;
- **edge cases on purpose**: ambiguity, misspellings, multi-turn context,
  adversarial inputs. Testing only typical inputs means production failures
  are discovered by users first;
- **mix synthetic and real traffic** where you have real traffic. Synthetic
  data speeds iteration but must reflect the real distribution.

Generate the **response side too**. For each case, produce responses of each
kind (complete, partial, workaround, escalation, vague/incorrect) so the
judge is tested on every grade, not just the easy passes. Decide up front how
workarounds, escalations and partial answers map to your labels; a binary
judge does not need a separate label per response type.

Two hygiene rules:

- **Keep eval data unseen.** Never reuse evaluation cases as few-shot
  examples in the thing being graded. That is data leakage.
- **One observed failure is a class.** When a case fails, generate more cases
  like it and fix the class; never hard-code a fix for the one case you saw.

Check the generated set before trusting it: quality, diversity, realism,
coverage gaps. A judge calibrated on a narrow set is only calibrated for that
narrow set.

## 2. Label a subset by hand: the answer key

Humans label a representative subset of runs. This subset is the ground truth
every judge metric is computed against. Keep the labels binary (pass/fail,
resolved/not-resolved) until the taxonomy is stable; graded scales multiply
the disagreement surface before you can even measure it.

## 3. Write the judge like code

The judge is a prompt with a job description, and it is writable, testable
and improvable exactly like code:

1. **Exact label definitions.** What counts as pass? Does "pass" require a
   complete fix, a workaround, or correct escalation?
2. **Boundary cases decided in advance**: the accurate-but-jargon-heavy
   answer, the correct redirect of an out-of-scope request, the partial
   resolution that needs one more user reply. Write the ruling into the
   rubric before running, not after seeing the judge wobble.
3. **Few-shot examples with reasoning**: a positive, a negative, and *why*
   each is what it is. The reasoning is the part that transfers.
4. **Low temperature** (≤ 0.2) so judgments repeat.
5. **Structured output** (e.g. JSON with a label and a one-line reason) so
   grading is a parser, not a string hunt.

## 4. Calibrate the judge: the four metrics

Before trusting the judge at scale, measure the judge itself against the
human-labeled subset. Start from the confusion matrix (for every run, one
cell of TP / TN / FP / FN) and **state which class is "positive"** next to
the numbers: swapping the convention swaps TPR and TNR and changes what
precision means.

With FAIL as positive (the usual choice when judging quality; a false
positive is then "the judge failed a run the human passed", i.e. too harsh):

| Metric | Formula | Question it answers |
|---|---|---|
| **TPR** (true positive rate; recall) | TP ÷ (TP + FN) | Of the runs humans failed, what share did the judge fail? |
| **TNR** (true negative rate; specificity) | TN ÷ (TN + FP) | Of the runs humans passed, what share did the judge pass? |
| **Accuracy** | (TP + TN) ÷ all | Overall agreement with humans. Hides which way the errors go. |
| **Precision** | TP ÷ (TP + FP) | Of the runs the judge failed, what share did humans also fail? |

(F1, the harmonic mean of precision and TPR, is a single number for
imbalanced classes; reach for it only when you must report one number.)

**Report all four, never accuracy alone.** A wide TPR–TNR gap is a
directional bias: TPR far above TNR is a lenient judge waving bad runs
through; the reverse is a harsh one failing good work. Accuracy is blind to
the difference: 85% correct could be either failure mode.

Worked example. 80 human-labeled runs: 50 FAIL, 30 PASS. The judge fails 44
of the 50 human-FAIL runs and passes 21 of the 30 human-PASS runs:
TP = 44, FN = 6, TN = 21, FP = 9.

| Metric | Calculation | Result |
|---|---|---|
| TPR | 44 ÷ 50 | 88% |
| TNR | 21 ÷ 30 | 70% |
| Accuracy | (44 + 21) ÷ 80 | 81.25% |
| Precision | 44 ÷ 53 | ≈ 83% |

TPR sits 18 points above TNR. Read the cells to name the bias: FP = 9 means
the judge failed 9 of the 30 runs humans passed (a 30% error rate on good
work), while FN = 6 means it waved through only 6 of the 50 runs humans
failed (12%). The errors lean **harsh**: it fails good work more than twice
as often as it passes bad work. Had the cells been reversed, the same
accuracy would describe a lenient judge. Either way: fix the rubric (sharper
label definitions, a few-shot aimed at the direction it errs in), re-judge,
and re-measure. Every disagreement is a rubric bug before it is a model bug.

At small sample sizes report the **counts alongside the rates**: TPR 0.88
over 50 labeled runs is a measurement; over 6 it is noise dressed up as a
percentage.

## 5. Judge metrics ≠ system metrics

Keep two dashboards separate:

- **Judge metrics** (TPR, TNR, accuracy, precision) measure the *judge
  against humans*. A judge can agree perfectly with humans about a system
  that is failing.
- **System metrics** measure the thing you shipped: pass rate per dimension,
  failure rate per category (login, billing, crash...), percent resolved per
  issue type, plus business outcomes (execution rate, escalation rate,
  latency). Compute them per category while iterating, not only globally; an
  aggregate can hold still while a category burns.

For **agents**, judge outcome plus process sanity, never step sequences:
different valid paths reach the same answer, so grade decision quality and
final-output correctness, with budgets (max steps, cost, timeout) and
tool-error counts in the report. Prefer unambiguous checks (the project's
real tests) over judgment wherever possible.

For **RAG**, retrieval metrics are leading indicators: Recall@k,
Precision@k, MRR on the retrieval side *before* touching generation; then
citation accuracy and faithfulness on the answer side. Fix retrieval first:
a faithful generator over a broken retriever still fails.

## 6. Example code

A calibration harness in plain Python: the confusion matrix, the four
metrics, and a judge loop skeleton. The `llm()` call is a placeholder for
whatever client you use; everything else is dependency-free.

```python
import json
from dataclasses import dataclass

@dataclass
class Confusion:
    tp: int = 0
    tn: int = 0
    fp: int = 0
    fn: int = 0

def confusion(human, judge, positive="FAIL"):
    # human/judge: equal-length label lists; `positive` names the class
    # treated as positive; state it next to any number you report.
    c = Confusion()
    for h, j in zip(human, judge):
        if h == positive:
            if j == positive: c.tp += 1
            else:             c.fn += 1
        else:
            if j == positive: c.fp += 1
            else:             c.tn += 1
    return c

def metrics(c):
    def ratio(num, den):
        return round(num / den, 4) if den else None
    return {
        "TPR (recall)":      ratio(c.tp, c.tp + c.fn),
        "TNR (specificity)": ratio(c.tn, c.tn + c.fp),
        "accuracy":          ratio(c.tp + c.tn, c.tp + c.tn + c.fp + c.fn),
        "precision":         ratio(c.tp, c.tp + c.fp),
        "counts":            {"TP": c.tp, "TN": c.tn, "FP": c.fp, "FN": c.fn},
    }

JUDGE_PROMPT = """You grade whether the response resolved the user's issue.
Label definitions: PASS means ... ; FAIL means ...
Boundary cases: a correct workaround is PASS; an accurate but jargon-heavy
answer is PASS; an out-of-scope request correctly redirected is PASS; ...

Example 1 (PASS, with reasoning): ...
Example 2 (FAIL, with reasoning): ...

User issue: {case}
Response: {response}
Answer with JSON only: {{"label": "PASS"|"FAIL", "reason": "..."}}"""

def judge(case, response, llm):
    out = llm(JUDGE_PROMPT.format(case=case, response=response), temperature=0.2)
    return json.loads(out)["label"]

# Calibration: judge the human-labeled subset, then read all four numbers.
run_pairs = [(row.case, row.response, row.human_label) for row in calibration_set]
human = [h for _, _, h in run_pairs]
judged = [judge(case, resp, llm) for case, resp, _ in run_pairs]
print(json.dumps(metrics(confusion(human, judged, positive="FAIL")), indent=2))
```

If TPR and TNR disagree widely, do not ship the judge: sharpen the rubric,
add a few-shot for the direction it errs in, re-judge, re-measure.

## 7. Gate with thresholds set before the run

Set pass thresholds before looking at results (choosing them after is
how A/B tests lie), keep a rollback path, and feed observed failures back as
new eval cases. The suite grows toward the stopping rule: add cases until
new traces stop producing new failure modes.
