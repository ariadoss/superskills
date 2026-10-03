# Eval run — Shannon Mode 5 + daily-qa drift wording (2026-10-02)

Post-change run of the full suite after `/pentest` gained Mode 5 (vendored,
agent-driven Shannon; description + body reworded, five modes) and
`/daily-qa` Step 4 gained the vendored-tool drift check. Same command as the
2026-10-02 daily-qa baseline (`claude plugin eval . --trust-plugin
--no-publish --judge-model sonnet --scaffold --allow-tools Bash`), so the
deltas read against that record (commit 9852487: mean Δ +0.17).

## Result

| Case | With | Without | Δ | Notes |
|---|---|---|---|---|
| doctor-ambiguous-readonly | 1.00 | 0.67 | +0.33 | |
| doctor-direct | 1.00 | 0.80 | +0.20 | |
| doctor-release-check | 1.00 | 0.67 | +0.33 | |
| doctor-symptom-missing-skill | 1.00 | 0.80 | +0.20 | |
| marketing-meta-description | 1.00 | 1.00 | 0.00 | |
| marketing-pricing-page | 1.00 | 1.00 | 0.00 | |
| offtopic-no-skill | 1.00 | 1.00 | 0.00 | negative control holds — the reworded pentest description does not over-trigger |
| quota-resume | 0.56 | 0.44 | +0.11 | reads-note fails in both arms — pre-existing, identical to baseline |
| quota-stop | 1.00 | 0.11 | +0.89 | |
| rate-limit-429 | 1.00 | 1.00 | 0.00 | |
| upgrade-not-doctor | 1.00 | 1.00 | 0.00 | |

**11 cases, mean Δ +0.19 (baseline +0.17). No regression; the suite has no
pentest-trigger case, so the Mode 5 wording change is measured only through
the negative controls — offtopic-no-skill stays 1.00/1.00, i.e. no false
triggering.** Cost $11.07, 1969s. Full artifacts: `evals/results/2026-10-02T22-53-14-755Z/` (gitignored).

Follow-up note: a dedicated pentest-routing case (e.g. "pentest this running
app" → Mode 5 selection) would measure the new mode's trigger directly; the
current suite predates it.
