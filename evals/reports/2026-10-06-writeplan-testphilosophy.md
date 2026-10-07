# Experiment E — Codex testing philosophy in /write-plan (structural close-out)

PREREG: `evals/reports/2026-10-06-writeplan-testphilosophy-PREREG.md`
(committed before any run, with two registered amendments, both before any
comparptive data existed). Intervention (never applied): verification
ordered specific→broad; no test frameworks into test-less repos; repair
loops bounded (3 attempts, then report).

## Result: CLOSED UNMEASURED — firing-power gate failed at every phrasing

| Phrasing | skill-fired | specific-first | no-framework | config |
|---|---|---|---|---|
| "my dotfiles repo… backup.sh" (original) | 0/3 | 0/3 | 3/3 | clean, single plugin |
| "our ops repo… pile of shell scripts" (amend 1) | 0/3 | 0/3 | 3/3 | contaminated (double plugin; this repo's copy) |
| "~40 hosts, cron, on-call" (amend 2, fleet weight) | 0/3 | 0/3 | 3/3 | contaminated (double plugin; this repo's copy) |
| (a sibling-worktree copy of the amend-1 case, run by the same commands under the same double-plugin config, fired 1/3 once — discarded as a contamination artifact, not evidence) | | | | |

**Correction (2026-10-06, qa-full red-team finding, verified against the
result JSONs):** an earlier version of this table credited the fleet
phrasing with the 1/3 fire. That fire belonged to the sibling worktree's
copy of the amend-1 case, matched into the run by the `--case` name glob
under a double-plugin configuration (both this repo and
`.worktrees/handoff-skill` were registered as superskills v2.37.0 — see the
suite.plugins arrays in testphil-baseline3/4.json). The first parser read
only `cases[0]`, which was the sibling's entry. This repo's fleet-phrasing
entry fired 0/3.

The preregistered firing gate (≥ 2/3) failed at every phrasing, so no
comparative arm ran and the skill edit was never applied. All rows above
are with-plugin runs in which write-plan failed to trigger (the suite ran
`--ablation none`; "plugin-less" in an earlier draft was wrong). Cost,
reconciled from the result JSONs: calibrations $0.65 + $1.30 + $1.50 =
$3.45, plus the $0.17 run discarded when the eval account hit its session
limit mid-run, plus the $2.46 guard run — E totals $6.08; with C2's $1.65,
round-2 spend is $7.73.

## The finding (corrected: flat under-firing; the gradient claim is retracted)

**Write-plan fired 0/3 on every utility-style phrasing tested** —
personal, team, and fleet weight alike — while the same day's
system-scale urgent ask ("worker queue backs up… reconciliation job")
fired 3/3 on the plan-quality case. The earlier dose-response/ask-weight
gradient claimed here was an artifact of the contamination documented
above and is retracted. What survives, consistent with the 2026-10-04
report's shape (0/3 docs-agent, 0/3 overreach, 1/3 simple-crud vs 3/3
batch/router): under-triggering on small/utility "plan this for me" asks
is a real, repeatedly observed gap in write-plan's description. Clean-run
evidence is thinner than the contaminated table suggests (only the
dotfiles phrasing ran single-plugin); a clean single-plugin re-run of the
ops and fleet phrasings is the follow-up if the number matters.

Subsidiary observation: in these with-plugin-but-untriggered runs,
`no-framework-imposed` scored 3/3 at every weight (the model honors an
explicit user constraint without the skill), while `specific-first` never
exceeded 1/3 — the testing-philosophy guidance has real headroom the day
the trigger fires.

## Disposition

- Case + graders kept as a permanent **firing-gap probe** (the suite's
  first case whose primary discriminators are verification-strategy
  shape).
- The intervention text is preserved verbatim in the PREREG for the day a
  description fix makes the case fire ≥ 2/3; rerun then is a two-command
  A/B.
- Follow-up (not run today; description-wording precision is a closed
  question per evals/README.md, but TPR-side under-firing is explicitly
  open): restructure write-plan's description toward utility-scale asks,
  gated on firing ≥ 2/3 here WITHOUT losing the offtopic negative
  controls.
