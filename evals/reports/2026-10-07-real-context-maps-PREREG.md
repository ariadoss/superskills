# PREREG — real-project utility test for repomap / dbmap / graphify

Registered before any run of the three cases. AMENDED 2026-10-07 before
any paid run, per the maintainer's mid-round correction: drop ats
("legacy") and otwarchive ("isn't mine") — no runs had occurred. Final
vehicles, all the maintainer's own GitHub-pushed repos: payroll-next
(VoltPay-AI/payroll, 1,146-file Next.js+Prisma monorepo) for BOTH the
repomap navigation test and the dbmap→audit composition; hyperion360
(the maintainer's content site, 589 docs) for graphify's corpus
questions. Notable in-situ fact: payroll-next already carries committed
DBMAP.md/REPOMAP.md/MIGRATION_TRACKER.md at root — the team has used
these tools on it — so arm C for payroll experiments is the repo
AS-IS (own artifacts present) and arms A/B are the same archive with
REPOMAP.md/DBMAP.md stripped by the scaffold. The synthetic-fixture
round (2026-10-06) returned mechanism-limited nulls (discovery failure,
task ceiling); this round tests each skill in its best-case habitat.

## Arms per experiment (same skeleton as the prior round)
A cold plain prompt · B skill-first (one inserted instruction line naming
the vendored toolchain/graph package) · C artifact pre-injected (generated
once host-side, byte-identical across C runs). B−A = policy effect;
C−A = ambient-artifact effect. n=3/arm, pilot framing: |Δ|<0.34 = no
signal at this scale; Δ≥+0.34 with no grader regression = signal,
licensing an optional n=5 confirmatory; skill-fired ≥2/3 required for
arm-B readings.

## Protocol carried from the prior round (registered there)
git-less /tmp rsync copy of THIS repo for runs; `--allow-tools 'Bash Edit
Write'`… (read-heavy tasks: Bash Read Grep Glob Skill suffice — Edit/Write
not needed, answers are replies) — commands use `--allow-tools Bash`;
`--max-cost-usd 6 --keep-temp`; scripts/eval-traces.sh after each;
single-plugin assertion before reading numbers; cumulative per-experiment
budget $18, plan total ≤ $54; pilot (1 run) precedes arms per experiment.

## Fairness
Graders grade replies against mechanically derived, committed ground
truths (GROUND_TRUTH.md in each case dir) — never vocabulary. Arm C
artifacts committed in case dirs; the out-of-fixture read probe reports
any ../.. leakage per arm. Real projects are copied via git archive into
the sandbox; the user's real trees are never touched by agent runs.

## Registered deviations/risks
1. graphify's arm-B pipeline (build graph then answer) may exceed
   max_turns=30 building over 500 files — the pilot decides; if build
   alone exhausts the run, B records "pipeline infeasible in-budget" and
   arms A/C still read.
2. graphify's C artifact is graph.json + GRAPH_REPORT.md (+ wiki if the
   --wiki build succeeds host-side); B gets whatever the skill produces.
3. dbmap C artifact: full DBMAP.md incl. an Index Analysis authored per
   the skill's own recipe (as the prior round).
4. dbmap on payroll-next has NO live database in this environment (no
   tracked DSN); the audit works from schema.prisma + migrations + code.
   Registered consequence: arm B's /dbmap skill run may be infeasible
   headless (its DSN detection finds nothing, its interactive ask cannot
   be answered) — that outcome is recorded as the skill's headless
   finding, and arms A (artifacts stripped) vs C (repo's own committed
   DBMAP.md present) decide the artifact question.
5. graphify arm B uses the vendored graphifyy package
   (graphify-vendor/bin/graphify, PYTHONPATH-wired); hyperion360's own
   committed REPOMAP.md stays in the archive for all graphify arms
   (it is not the variable under test there; noted as ambient context).
