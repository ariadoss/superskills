# PREREG — clean-code ambition bar ("code judo")

Registered before any run of `cleancode-judo`. Provenance: cursor/plugins
`thermos/skills/thermo-nuclear-code-quality-review/SKILL.md` (fetched
2026-10-07) asks one more question per changed file — is there a reframe
that deletes a whole category of complexity? Adapted here as one subsection
of clean-code's audit step; it explicitly resolves the tension with the
skill's "Smallest safe refactor" hard rule: smallest stays the default fix;
the reframe is recorded and may be applied only when behavior-preserving,
test-covered, and strictly simpler. Host-agnostic by construction (markdown
skill-body edit).

Fixture design note: the fixture COMMITS the diff under review on the
`feature/export-yaml` branch (one base commit beneath it), so clean-code's
Step 1.4 clean-tree precondition holds without a user to ask, and the suite
is green on HEAD so Step 1.3 does not exit. The measured thing is SEEING the
reframe — audit quality; applying it is optional and suite-gated.

## Intervention (applied only between the two runs)

`skills/clean-code/SKILL.md` gains one subsection, "Ambition bar (the
audit's second question)", at the end of `## Step 2: Audit` (full text in
the plan): per changed file, ask whether a reframe deletes a whole category
of complexity — code judo, size smell, spaghetti growth, canonical layer —
recorded as `JUDO — file:line — the reframe — what it deletes`. A JUDO
finding may be applied as the fix only when behavior-preserving,
test-covered (characterization test first, like any other fix), and strictly
simpler; otherwise it stays UNFIXED with the reframe written out. Declared
UNMEASURED riders in the same edit: the ambition bar ships as four rules;
the fixture measures the reframe dimension — size-smell, spaghetti-growth,
and canonical-layer ride as declared-unmeasured, guarded by the
behavior-preserved and diff-scoped graders.

## Cases

| Case | Role |
|---|---|
| `cleancode-judo` (new) | primary: names-judo + behavior-preserved + diff-scoped |

## Fairness rule (fixed in advance)

Graders grade behaviour (whether the structural reframe was named, whether
the suite stayed green, whether fixes stayed in the diff), never vocabulary.
skill-fired graders are unscored indicators. Boundary rulings are in the
grader texts, committed before runs.

## Endpoints and thresholds (set before the runs)

- Price calibration: one `--runs 1` run of `cleancode-judo`:
  `claude plugin eval . --case cleancode-judo --runs 1 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 6 --json evals/results/judo-price.json`.
  ABORT (keep cases, report the price) if it exceeds $5.
- Runs: `--ablation none`, 3 runs/case/arm, both arms same day.
  Baseline:
  `claude plugin eval . --case cleancode-judo --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 15 --json evals/results/judo-baseline.json`.
  Change: the same command as the baseline run with
  `--json evals/results/judo-change.json`.
  Budget: baseline `--max-cost-usd 15`, change `--max-cost-usd 15`
  (≤ $36 total with the price run).
- **Firing-power gate:** clean-code fires in ≥ 2/3 runs in BOTH arms on the
  primary case. Below that: under-powered, adopt nothing.
- **Primary:** mean of names-judo + behavior-preserved + diff-scoped over
  3 runs, change vs baseline.
- **Adopt** if: names-judo ≥ +0.15 AND primary ≥ +0.10 AND
  `cleancode-judo`/behavior-preserved does not regress at all AND
  `cleancode-judo`/diff-scoped does not regress ≥ 0.34 AND the firing gate
  holds.
- **Reject** otherwise: revert the skill edit, keep cases + PREREG, report
  the null. A null is a real answer.
- Stated limit: n=3; same-day drift between the two sequential runs is an
  uncontrolled small confound (precedent: 2026-10-06 calibration report).
