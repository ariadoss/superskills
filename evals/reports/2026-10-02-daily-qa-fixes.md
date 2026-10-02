# Eval run — 2026-10-02, after the daily-qa fix batch

Run: `claude plugin eval . --trust-plugin --no-publish --judge-model sonnet
--scaffold --allow-tools Bash` on HEAD `63e25d4` (the four daily-qa fix
commits: doctor-lib manifest/rc, bridge hardening, setup guards, plus the
humanize README pass). 11 cases, with/without ablation, 3 runs per arm,
1970s, $10.86.

## Result

| Case | with | without | Δ |
|---|---|---|---|
| doctor-ambiguous-readonly | 1.00 | 0.75 | +0.25 |
| doctor-direct | 1.00 | 0.80 | +0.20 |
| doctor-release-check | 1.00 | 0.72 | +0.28 |
| doctor-symptom-missing-skill | 1.00 | 0.80 | +0.20 |
| marketing-meta-description | 1.00 | 1.00 | 0 |
| marketing-pricing-page | 1.00 | 1.00 | 0 |
| offtopic-no-skill | 1.00 | 1.00 | 0 |
| quota-resume | 0.56 | 0.56 | 0 |
| quota-stop | 1.00 | 0.11 | +0.89 |
| rate-limit-429 | 1.00 | 1.00 | 0 |
| upgrade-not-doctor | 1.00 | 1.00 | 0 |

Mean Δ +0.17. Full report: `evals/results/2026-10-02T14-50-59-818Z/report.html`
(gitignored; the numbers above are the durable copy).

## Reading

- No regression from the fix batch: every case the morning baseline
  (`evals/results/2026-10-02T03-12-33-484Z`, pre-fixes) scored at ceiling
  stays at ceiling, and the doctor/quota-stop ablation deltas are unchanged
  in direction and magnitude.
- **quota-resume 0.56/0.56 is pre-existing**, identical to the pre-fix
  baseline (0.556/0.556, Δ 0): the failing grader is `reads-note` — "Read
  called 0x (expected 1..∞)" in both arms. The scaffolded session completes
  the work but never Reads the committed QUOTA-RESUME.md. Not caused by the
  fix batch (nothing in it touches the quota path); root-causing needs a
  `--keep-temp` run to inspect the trace, and is the open follow-up.
- The bridge token-path change (pentest SKILL.md launch snippet) has no
  dedicated eval case; its behavior is pinned by
  `tests/pentest-bridge.bats` (17 tests) instead.
