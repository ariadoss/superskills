# Lexical baseline vs model triggering

Codex evaluates skill selection with deterministic selectors in shadow mode
(`codex-rs/ext/skills/src/shadow_selection_experiment/` — BM25, n-gram,
lexical and LRU variants, "cheap enough to run in shadow mode on every
turn"). We cannot run their production telemetry; the local reduction is
`evals/_lib/lexical-baseline.py`: BM25 (k1=1.5, b=0.75) over every skill's
frontmatter, with the answer key derived from each case's `skill-fired`
grader. One command, zero model cost.

## Table (2026-10-06, worktree @ Experiment A baseline state)

| case | expected | bm25 top-1 | hit |
|---|---|---|---|
| doctor-ambiguous-readonly | superskills-doctor | superskills-doctor | ✓ |
| doctor-direct | superskills-doctor | superskills-doctor | ✓ |
| doctor-release-check | superskills-doctor | superskills-doctor | ✓ |
| doctor-symptom-missing-skill | superskills-doctor | clean-code | ✗ |
| marketing-meta-description | meta-description | excluded (out-of-catalog) | - |
| marketing-pricing-page | pricing-page-generator | excluded (out-of-catalog) | - |
| offtopic-no-skill | (no key) | - | - |
| quota-resume | quota-resilience | quota-resilience | ✓ |
| quota-stop | quota-resilience | quota-resilience | ✓ |
| rate-limit-429 | (no key) | - | - |
| review-calibration | basic-review | basic-review | ✓ |
| review-clean | basic-review | basic-review | ✓ |
| upgrade-not-doctor | (no key) | - | - |
| writeplan-batch-classify | write-plan | basic-review | ✗ |
| writeplan-docs-agent | write-plan | basic-review | ✗ |
| writeplan-judge-loop | write-plan | tapestry | ✗ |
| writeplan-overreach | write-plan | kb-advisor | ✗ |
| writeplan-plan-quality | write-plan | tapestry | ✗ |
| writeplan-router-intake | write-plan | write-plan | ✓ |
| writeplan-simple-crud | write-plan | basic-review | ✗ |

**Top-1 accuracy over keyed in-catalog positives: 8/15 = 0.53.** Negatives
(no-skill-fired cases) are excluded: a forced-choice ranker cannot abstain,
so true-negative rate is structurally unmeasurable here — that is where
model judgement earns its cost.

## Comparison — denominators

The baseline's number is **top-1 accuracy over keyed in-catalog positives
only**. The model's TPR covers the same positives; its TNR (the negatives)
has no baseline counterpart. Compare TPR-to-top-1 only:

| Slice | Model (TPR, cited) | Lexical (top-1) | Reading |
|---|---|---|---|
| doctor-* | 12/12 under `claude plugin eval` (`evals/README.md`, routing section) | 3/4 | both near ceiling; the miss (doctor-symptom-missing-skill → clean-code) is a description-overlap case |
| writeplan-* | 9/15 (`evals/reports/2026-10-04-orchestration-checklist.md`: 3/3 batch, 3/3 router, 2/3 judge-loop, 0/3 docs-agent, 1/3 simple-crud, 0/3 overreach) | 1/7 | **model judgement earns its cost** — the case prompts say "plan this for me" while routing signals live in write-plan's description body ("spec", "engineering plan", "TDD tasks"); a keyword ranker cannot bridge that gap |
| review-* | no model number yet (Experiment A runs, 2026-10-06) | 2/2 | prompt contains "a basic review is fine" — trivial lexical overlap; treat as unmeasured for the model until Experiment A's skill-fired counts land |
| quota-* | no recent model number | 2/2 | description carries "quota"/"usage limit"; easy lexical case |

## Verdict

- **Model judgement earns its cost on the routing slice that matters.** On
  the writeplan slice the model scores 0.60 TPR against the ranker's 0.14,
  and the model's TNR (abstaining on offtopic-no-skill etc.) has no
  deterministic counterpart at all. No deterministic pre-filter is justified
  on this evidence.
- The baseline's value is as a **floor row for future routing reports**: if
  a description edit cannot beat 0.53-from-a-keyword-ranker, it did not
  improve routing. It also localizes *which* prompts are lexically easy
  (doctor/quota/review) versus judgement-loaded (writeplan), which is useful
  when writing new case prompts.
- **Adopted: include this row in future routing reports** (one command, zero
  model cost; 15 keyed in-catalog cases, above the 5-case vacuity floor from
  the PREREG template).
