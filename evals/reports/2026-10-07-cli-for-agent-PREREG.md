# PREREG — cli-for-agent vendored new-skill A/B (cli-agents-quality)

Registered before any run of `cli-agents-quality`. Provenance: cursor/plugins
`cli-for-agent/skills/cli-for-agents/SKILL.md` (MIT), vendored whole with
attribution and `metadata.upstream` (full skill text in the plan). Distinct
from the 2026-10-07 basic-review and clean-code experiments (skill-body edits
to already-installed skills): this is a NEW-SKILL A/B, and the skill itself is
created only AFTER the baseline run — `claude plugin eval .` loads skills from
the repo working tree, so a `skills/cli-for-agent/` directory that is present
but uncommitted would still fire and contaminate the baseline.

## Intervention (applied only between the two arms)

The tree gains `skills/cli-for-agent/SKILL.md` (the vendored skill, full text
in the plan) plus its `./setup` link. There is no pre-existing skill behavior
to improve from within; the claim under test is that the skill's agent-friendly
CLI patterns add measurable quality over what the model builds unprompted.

## Cases

| Case | Role |
|---|---|
| `cli-agents-quality` (new) | primary: the four outcome graders |
| `offtopic-no-skill` (unchanged) | global negative guard: no skill-firing in the treatment arm |

## Fairness rule (fixed in advance)

Graders grade the shown evidence — what the `--help` output contains, what a
missing-required-flag run prints, what a successful `add` prints, whether
duplicate adds and overwrites are guarded — never skill vocabulary. Graders see
the **final message only**, so the prompt explicitly demands the evidence be
shown in the reply (`--help` output, the missing-flag error run, the success
output) — a build whose evidence lives only in tool calls scores 0 on the
outcome graders; this prompt-shape dependency is declared here rather than
discovered later. skill-fired graders are unscored indicators. The fixture
domain (book inventory: `shelfy`) is disjoint from the skill's `mycli deploy`
examples (anti-leakage per `evals/METHODOLOGY.md`).

## Endpoints and thresholds (set before the runs)

- Price calibration: one `--runs 1` run of `cli-agents-quality`
  (`--max-cost-usd 5`). ABORT (keep cases, report the price) if it exceeds $4.
- Runs: `--ablation none`, 3 runs/case/arm, both arms same day. `--case` takes
  a single glob and `cli-agents-quality`/`offtopic-no-skill` share no prefix,
  so each arm is TWO invocations: `cli-agents-quality` at `--max-cost-usd 9`,
  `offtopic-no-skill` at `--max-cost-usd 3`.
- Budget: baseline $12, change $12 (≤ $29 total with the price run).
- **Firing gate (treatment arm):** cli-for-agent fires in ≥ 2/3 runs on
  `cli-agents-quality`. Below that the experiment is VOID, not a reject: the
  skill is unreachable — report, revisit the description, do not adopt.
- **Primary:** mean of the four outcome graders (non-interactive,
  help-examples, errors-actionable, repeat-safe) over 3 runs, change vs
  baseline.
- **Adopt** if: primary ≥ +0.15 AND the firing gate holds AND
  `offtopic-no-skill` records no skill-firing in the treatment arm AND no
  outcome grader regresses ≥ 0.34 (a baseline run can pass a grader without
  the skill — the gates catch a skill that makes the CLI *worse*).
- **Reject** otherwise: remove `skills/cli-for-agent/`, re-run `./setup`, keep
  case + PREREG, report the null. A null is a real answer.
- **Rider declaration:** the skill ships whole; the four graders sample its
  highest-risk patterns (non-interactive, help examples, actionable errors,
  idempotency). The remaining sections (stdin/pipelines, discoverability,
  predictable structure, success output) are guarded only by the regression
  cases.
- Stated limit: n=3; same-day drift between the two sequential runs is an
  uncontrolled small confound (precedent: 2026-10-06 calibration report).
