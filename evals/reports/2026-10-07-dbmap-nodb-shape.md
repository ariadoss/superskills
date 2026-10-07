# dbmap in the no-live-DB scenario — the maintainer's concern, tested

PREREG: `2026-10-07-dbmap-nodb-PREREG.md` (+ one registered instrument
repair: the real migrations carry the indexes, so the divergence was
planted — migration lines replaced with a "-- index dropped in 2026-09
hotfix" comment, DBMAP.md the only live-DB truth bearer; and one
registered protocol repair: a mislabeled arm-C ran under A-conditions
when a fixture edit hit the wrong tree — controller error, discarded,
re-run). One mislabeled-arm cost $1.42; total $5.66.

## Results (n=3/arm, planted-stale world)

| Arm | shape-correct | evidence-honest | turns | cost |
|---|---|---|---|---|
| A cold (stale migrations, no map) | **0/3** | 3/3 | ~9 | $1.19* |
| C (stale migrations, map present + repo's own .claude/rules/dbmap.md pointer) | **0/3** | 3/3 | 10-12 | $1.63 |
(*calibration run under true migrations scored 2/3 — see repair.)

## What actually happened (traces, all three C runs)

Every map-bearing run READ DBMAP.md, cross-referenced it against
schema.prisma AND the migrations, and correctly refused to guess:
- All three identified the map as a real tbls dump but UNDATED and
  UNSOURCED ("Generated from: manual --dsn" — which database? when?).
- All three content-dated it (~early June 2026; missing deleted_at and
  later tables) and judged it ~4 months stale.
- All three DETECTED THE PLANTED FORGERY — "migration files were
  hand-edited; no dropping migration exists; nothing else records the
  hotfix; could just be a careless edit."
- All three answered "unknown, sources disagree, low confidence" — the
  epistemically correct answer given undated conflicting sources. One
  bounded Q1 via InnoDB FK-requires-index logic.

## The verdict on the maintainer's concern

1. The observed failure mode did not reproduce as confident wrongness:
   with conflicting sources, current models hedge honestly rather than
   confidently guessing from migrations. The 0/3 is the GRADER's key
   demanding a confident YES from evidence that warrants "unknown."
2. What defeats the stale-map problem is METADATA, not more maps: three
   independent agents flagged the same missing fields — generation
   timestamp, source-database identity, generator. A provenance-stamped
   DBMAP.md would have resolved the conflict (in either direction).
3. The repo's wired pointer (.claude/rules/dbmap.md) WORKS — agents
   followed it in every arm, including reporting its dangling state when
   the map was stripped.

## Disposition feeding the keep/remove decision

- repomap: REMOVE (three nulls incl. the team's own committed map).
- graphify: REMOVE (directional negative + 2x turn cost; one-experiment
  basis noted).
- dbmap: KEEP, REPURPOSED — its job is generating the ground-truth
  artifact and wiring the pointer, not run-first context injection. The
  high-value edit (gated follow-up): stamp DBMAP.md's header with
  generation time, source database identity, and DSN target, per the
  three runs' independent diagnosis. With provenance stamped, re-run
  this case: the prediction flips to C > A.
