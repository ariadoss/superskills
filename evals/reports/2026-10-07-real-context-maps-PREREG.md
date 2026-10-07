# PREREG — real-project utility test for repomap / dbmap / graphify

Registered before any run of the three new cases. The synthetic-fixture
round (2026-10-06) returned mechanism-limited nulls (discovery failure,
task ceiling). This round re-tests each skill in its best-case habitat on
REAL projects from ~/Sites: ats (Go+PocketBase/sqlite, 1,187 files) for
the dbmap→audit composition; songs (504 txt + mapping hub, cross-document
relational questions) for graphify; otwarchive (Rails monolith, 2,707
files) for repomap navigation.

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
4. Real-repo scaffold sizes: otwarchive ~2.7k files, ats ~1.2k + the
   8-month-old backup .db (the live schema stand-in; registered as a
   staleness risk the audit question itself surfaces).
