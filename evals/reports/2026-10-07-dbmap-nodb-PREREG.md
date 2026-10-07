# PREREG — dbmap in the no-live-DB scenario (the maintainer's concern)

Registered before any run. Hypothesis (maintainer's observation): agents
without DB access GUESS the database shape from migration files instead
of exporting SQL — and a committed DBMAP.md (live-DB-derived) prevents
the wrong guesses. This is a different job than every prior dbmap arm:
not "run the skill first" (the toll) but "does the ground-truth artifact
change answers on questions where migrations mislead."

Vehicle: payroll-next again — the no-DSN premise is REAL, the
migrations/prisma genuinely lack Q1/Q4's indexes (reconciliation debt,
2026-10-07 report), and the committed DBMAP.md carries the live-DB DDL.

## Arms (2 — B dropped, registered)
A cold: scaffold strips DBMAP* / REPOMAP / MIGRATION_TRACKER (the
   guessing-from-migrations world the maintainer observed).
C: repo as-is — committed DBMAP.md present, plain identical prompt.
B (/dbmap first): dropped — no DSN exists in-env; the headless
   infeasibility is already registered twice. A vs C is the decisive
   comparison for the concern.

## Prediction registered in advance
If the maintainer's concern is right: A answers Q1/Q4 NO (migration
guess) or hedges; C answers YES (map read). Δ(C−A) ≥ +0.34 on
shape-correct → dbmap EARNS its keep as a committed ground-truth
artifact for no-access work; keep the skill for generating/refreshing
the map, drop the run-first toll framing. If C ≡ A: the artifact doesn't
rescue the guess either; removal proceeds for all three.

## Gates
n=3/arm; primary = shape-correct; pilot framing (±0.34); caps $4; total
≤$8; single-plugin + git-less-copy protocol as prior rounds; graders
grade answers vs the committed live-DB key, never vocabulary.

## Amendment (instrument repair, before comparative arms; 2026-10-04 precedent)

Arm A's first execution ($1.19, discarded as calibration) scored
shape-correct 2/3 — because the premise was FALSE: the real migrations
DECLARE both indexes (raw INDEX clauses; only schema.prisma's annotations
lag). Guessing from these migrations is guessing right. The fixture now
plants the divergence (migration lines replaced with "-- index dropped in
2026-09 hotfix"; valid SQL), making DBMAP.md the only truth-bearer in arm
C. Prediction unchanged: A misled (NO/hedge), C correct (YES). Also
corrects the 2026-10-07 report's reconciliation claim: the repo's debt is
prisma-annotation drift, not DB-vs-repo drift.
