# Real-project context-map utility — final round (payroll-next, hyperion360)

PREREG: `2026-10-07-real-context-maps-PREREG.md` (amended once for the
maintainer's vehicle correction, one instrument repair registered before
arms — the repomap key was prisma-centric and wrong; the cold pilot's
answer found the true Frappe-backend architecture). All runs single-plugin
verified; git-less /tmp copy protocol; caps $3-6/command.

## Results (n=3/arm, with-plugin, sonnet judge)

| Experiment | Arm | Primary | Key graders | Turns | Cost |
|---|---|---|---|---|---|
| R repomap @ payroll-next (1,146 files) | A cold (artifacts stripped) | 0.500 | nav 2/3, no-fab 1/3 | 18.3 | $1.71 |
| | B /repomap first (fired 3/3) | 0.500 | nav 1/3, no-fab 2/3 | 17.3 | $1.82 |
| | C repo's OWN REPOMAP.md present | 0.333 | nav 2/3, no-fab 0/3 | 16.0 | $1.72 |
| D dbmap audit @ payroll-next | A cold | 0.500* | audit 0/3, honest 3/3 | 19.0 | $2.48 |
| | B /dbmap first (fired 3/3, adapted to no-DSN) | 0.500* | audit 0/3, honest 3/3 | 18.0 | $2.78 |
| | C repo's OWN DBMAP.md present | 0.500* | audit 0/3, honest 3/3 | 16.0 | $2.45 |
| G graphify @ hyperion360 (589 docs) | A cold | 1.000 | relational 3/3, evidence 3/3 | 11.0 | $1.57 |
| | B /graphify first (fired 3/3) | 0.833 | relational 2/3, evidence 3/3 | 20.7 | $2.11 |

*D's "primary" is the honest-findings grader only; the completeness
grader was 0/3 in every arm (see the confound below).

## Verdicts (pilot framing, ±0.34 signal rule)

- **repomap: NULL at real-repo scale** — Δ(B−A)=0.000, Δ(C−A)=−0.167.
  The third consecutive null, now including the team's own committed map
  sitting in the repo. The vendored toolchain ran 3/3 in-sandbox.
- **dbmap: ILL-POSED rather than null** — no arm (9/9 runs) found ≥5 of
  the 8 schema.prisma relation-without-@@index gaps within 30 turns, AND
  the fixture exposed why any map-vs-cold comparison on this question
  confounds: **the repo's own two schema sources disagree** (live-DB map
  shows employer_login_directories_tenant_id_idx & chat_messages composite
  indexes; schema.prisma's relation fields carry no @@index). Until an
  authoritative source is declared, the map can mislead a source-level
  audit — reported to the maintainer as reconciliation debt, not measured
  around.
- **graphify: NULL, directionally negative, with the by-now-familiar cost
  signature** — Δ(B−A)=−0.167, turns 11.0→20.7 (+88%), +34% dollars.
  The corpus questions anchor on ~6 greppable docs; the graph build
  consumed ~10 turns before answering and dropped a point doing it.

## The cross-round pattern (synthetic 2026-10-06 + real 2026-10-07)

Five experiments, five null-or-negative results for running-or-carrying
context maps, across toy fixtures, a real monorepo, and a real corpus:
**for every question shape we could pose, targeted search of a few
anchors beat or tied broadcast maps and graph pipelines at lower cost.**
The only consistently measured effect of invoking these skills first is a
1.3–2× turn cost. The conditions under which that could flip — corpus
large enough that anchor-finding dominates, questions relational rather
than locational, a consumer that queries the index instead of loading it —
were each partially present somewhere and never together.

## Instrument notes (for reuse)
- The R key repair is the round's methodological story: the cold pilot
  FAILED a correct answer, verification read the reply, and the key — not
  the run — was wrong (notifications are Frappe-owned; no prisma model).
- The sealed-$HOME scaffold needs absolute paths everywhere (three
  fixtures fixed at the repo, one wasted pilot).
- G's arm C was infeasible by design discovery (graphify's build is
  agent-driven; no host-side one-shot builder) — registered, A/B ran.

Spend this round: $19.15 (R $5.25 + 2 pilots $1.06; D $7.71; G $3.68 +
$0.47 G pilot... exact: 1.71+1.82+1.72 +2.48+2.78+2.45 +1.57+2.11 +0.59+0.47).
