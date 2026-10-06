# Eval run — orchestration-shape checklist in /write-plan (2026-10-04)

Tested: does inlining a PocketFlow-derived pattern taxonomy (pipeline,
map-reduce, agent loop, judge loop, router, vote/debate + boundary
disciplines: structured output, retry-with-fallback, uncertainty→human
fallbacks, human gates, simplest-shape-wins) as a naming checklist in
`/write-plan` improve plans for LLM-driven features? Preregistration and two
calibration passes: [`2026-10-04-orchestration-checklist-PREREG.md`](
2026-10-04-orchestration-checklist-PREREG.md). Design: `--ablation none`
(with-plugin arm only — the question is whether the edit improves write-plan's
own output), 3 runs/case, 6 new cases, sonnet judge, identical command both
configurations:

```bash
claude plugin eval . --case 'writeplan-*' --ablation none -j 2 \
  --trust-plugin --no-publish --allow-tools Write --judge-model sonnet \
  --max-cost-usd 40 --json evals/results/writeplan-{baseline-v2,change}.json
```

## Result (registered endpoint)

| Case | Baseline | Change | Δ | Notes |
|---|---|---|---|---|
| writeplan-batch-classify | 0.83 | 0.83 | 0.00 | 1 timeout each arm (600s); design grader 2/3 both |
| writeplan-docs-agent | 0.33 | 0.50 | +0.17 | skill fired 0/3 in both arms (routing gap, below) |
| writeplan-judge-loop | 0.83 | 0.67 | −0.16 | one firing flip, description unchanged |
| writeplan-router-intake | 0.50 | 0.83 | +0.33 | llm grader 0/3 → 3/3 |
| **primary: mean, 4 positives** | **0.625** | **0.708** | **+0.083** | adopt bar was ≥ +0.10 |
| writeplan-overreach (control) | 0.50 | 0.50 | 0.00 | no over-restriction of minimal designs |
| writeplan-simple-crud (control) | 0.67 | 1.00 | +0.33 | no AI machinery 3/3; skip-clause did not over-trigger |

**Verdict: REJECTED by the pre-registered threshold** (+0.083 < +0.10). The
write-plan and ENGINEERING_STANDARDS edits were reverted; the diff lives in
this report's appendix trail (`git stash`-free: re-derive from PREREG §1).
Cost: $40.79 total ($10.74 superseded baseline, $15.19 baseline, $12.33
change, $2.53 calibration debug runs), 36 + 18 scored runs.

## Judge calibration (FAIL positive, n=36 labeled)

TP=6, TN=30, FP=0, FN=0 → TPR 1.00, TNR 1.00, accuracy 1.00, precision 1.00.
Counts, not significance: the five BASE failures were the two truncated
timeout replies, docs-agent r2 (hybrid loop design whose stop-conditions and
human gate were not demonstrably in the reply), and router ×3 (see below);
both CHANGE-arm failures were timeouts. Labeling was done with judge outcomes
visible, so read this as agreement, not independent validation. Internal
judge votes were near-unanimous (one 1/2 split in 36).

## Exploratory decomposition (post-hoc — does not override the verdict)

The registered endpoint mixes skill-firing (an indicator under with-without,
but scored under `--ablation none`) with design quality. Split:

- **Design quality (llm graders only), positives:** baseline 7/12 → change
  11/12 (+0.33). The whole router movement (0/3 → 3/3) lands on the
  checklist's distinctive teaching — uncertain/refused/unparseable
  classifications surfacing to a human, which zero baseline designs had and
  change-arm designs did.
- **Skill firing, positives:** 8/12 → 6/12. Two flips (judge-loop r2,
  router r1) with an unchanged `description` — run-to-run trigger noise that
  cost the registered endpoint ~0.17.

Read honestly: the checklist improved design decisions where the skill fired
and its content was the missing piece; the registered bar was missed by
0.017 with n=3 runs/case, where a single firing flip moves the primary mean
by 0.083. Under-powered, directionally positive, not adopted per the rule.

## Product finding (independent of the verdict)

**write-plan under-fires on greenfield/product asks**: 3/3 on
infrastructure-flavoured prompts (batch, router) and 2/3 on judge-loop, but
0/3 on docs-agent and overreach ("plan this for me" / "sketch me a plan" on
an empty repo) and 1/3 on simple-crud, across both arms. Those asks read as
design/brainstorm territory rather than "spec in hand". A routing case like
`writeplan-docs-agent` stays in the suite as the standing measurement;
fixing the description is a separate behaviour change with its own eval.

## Known limits

- No same-run no-plugin arm (PREREG amendment): same-day model drift is an
  uncontrolled small confound.
- One 600s timeout per arm (batch-classify): those two runs were graded on
  truncated replies and scored 0.5; both arms equally exposed.
- Empty-repo greenfield: every run invented a stack; realistic for this ask
  but not for in-codebase planning.
- Graders see `last_message` only; plans saved to files without in-reply
  architecture would score artificially low (prompts explicitly requested
  in-reply architecture to hold this constant).
- `focus: last_message` grading means the file-saved plan's full content is
  unmeasured.

## Follow-ups (offered, not taken)

1. Powered re-run of router + judge-loop + docs-agent at 7 runs/case
   (~$15–20) to settle the under-powered primary.
2. Adopt by override: the +0.33 design-quality signal with clean controls
   would justify shipping if the owner accepts the registered bar was
   mechanical.
3. write-plan routing gap: description rewording for greenfield "plan this"
   asks, eval'd as its own behaviour change.
