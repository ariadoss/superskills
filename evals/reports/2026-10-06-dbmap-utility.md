# dbmap utility — A/B/C pilot results (2026-10-06)

PREREG: [`2026-10-06-dbmap-utility-PREREG.md`](2026-10-06-dbmap-utility-PREREG.md)
(committed at `bd83eaa` before any run). Case `dbmap-schema-task`, n=3/arm,
one case per invocation, judge `sonnet`, every command `--max-cost-usd 4`
(pilot 2) `--keep-temp`, traces archived via `scripts/eval-traces.sh`.
Result JSONs: `results/dbmap-{pilot,armA,armB,armC}.json` (local,
git-ignored) + `results/dbmap-*-traces*/`.

## Pilot (before any arm)

One paid pilot (1 run of the arm-B prompt, $0.379) verified every
registered gate condition in-sandbox: the skill fired
(`superskills:dbmap`), the vendored toolchain executed inside
`./fixture-repo` (`REPOMAP_HOME=$PWD/vendor vendor/scripts/run.sh dbmap
--list` then `--dsn 'sqlite:///…' -o DBMAP.md`), tbls 1.94.4 resolved on
PATH (no install attempt), DBMAP.md was written and the agent appended
its own `## Index Analysis`, and **no stall occurred on the skill's
interactive "which connection?" question** — the prompt's ".env —
that's the only connection" steering answered it in advance.

One harness fact surfaced and was contained: the CLI (2.1.292) defaults
to a `with-without` ablation, so the pilot command also ran an
unregistered no-plugin baseline ($0.335, total command $0.714). That
baseline is meaningless for this design — the B prompt itself names the
vendored toolchain, so the "without" agent ran it manually anyway
(trace-verified) — and every subsequent command passed `--ablation none`
(matching the repomap runs' result shape). Not arm data.

## Single-plugin check (after every command, before reading numbers)

All four commands (pilot + 3 arms) ran from the git-less rsync copy at
`/tmp/superskills-eval-copy`, refreshed from the worktree immediately
before each arm so the uncommitted arm state (B prompt / C artifact
copy) was what ran. Every result JSON recorded exactly
`[('superskills', '/private/tmp/superskills-eval-copy')]` — one plugin,
no `worktrees` path, no main-checkout entry. 4/4 clean.

## Per-arm results

Graded pass-rates (n=3/arm; no run truncated: all `err=None`, max turns
used 10 of 30):

| grader | A cold | B skill-first | C map pre-injected |
|---|---|---|---|
| skill-fired (indicator) | 0/3 | **3/3** | 0/3 |
| task-correct (llm) | 3/3 | 3/3 | 3/3 |
| no-wrong-edits (llm) | 3/3 | 3/3 | 3/3 |
| schema-inspected (indicator) | 3/3 | 3/3 | 3/3 |
| **Primary = mean(task-correct, no-wrong-edits)** | **1.000** | **1.000** | **1.000** |

Secondary (reported only; no truncated runs to exclude):

| metric | A | B | C |
|---|---|---|---|
| mean turns | 4.3 (4,4,5) | 9.0 (10,8,9) | 4.0 (4,4,4) |
| mean durationSeconds | 36.3 (42,34,33) | 50.3 (57,45,49) | 27.7 (25,27,31) |
| mean Bash calls | 3.3 | 6.0 | 3.0 |
| Read/Grep/Glob tool calls | 0/0/0 | 0/0/0 | 0/0/0 |
| out-of-fixture reads | 0 | 0 | 0 |
| cost per arm (3 runs) | $0.659 | $1.032 | $0.729 |

Exploration is Bash-carried (as in the repomap runs): the Read/Grep/Glob
tool metric reads 0 across all 9 runs while every run explores via
`cat`/`find`/`sqlite3` inside Bash. Out-of-fixture read probe: **0 reads
outside ./fixture-repo in all 9 runs** (the `$TMPDIR` app.db copies runs
make to test indexes are scratch writes, not reads of workspace content;
the vendored toolchain lives inside the fixture).

## Gate arithmetic (pre-registered)

- skill-fired gate, arm B: **3/3 ≥ 2/3 — powered**, a verdict is permitted.
- Δ(B−A) primary = 1.000 − 1.000 = **0.000**.
- Δ(C−A) primary = 1.000 − 1.000 = **0.000**.
- |Δ| < 0.34 everywhere → **"no signal at this scale"** for both
  comparisons; no n=5 confirmatory is licensed.

**Verdict row: B≡A≡C → null at this scale.** The mechanism is a
**ceiling effect**: arm A's cold runs solve the task perfectly with two
sqlite3 commands, so the map has no correctness headroom to add — it can
only cost time (B) or save noise-level time (C).

## Trace observations

- **Arm B engaged the map every time**: fired /dbmap (3/3), ran the
  vendored toolchain inside fixture-repo (3/3), generated DBMAP.md
  (3/3), appended its own `## Index Analysis` (3/3), read it back
  (3/3). The intervention was delivered as designed — at roughly double
  the turns (9.0 vs 4.3), +38% duration, and +57% per-run cost
  ($0.344 vs $0.220). Same direction as repomap's arm B, larger.
- **Arm C DID read the pre-injected map — 3/3** (a root-level DBMAP.md
  is swept in by every run's opening `cat` of the repo root; the
  repomap experiment's REPOMAP.md was read 0/3). But reading it changed
  nothing observable: every C run still ran its own `sqlite3 .schema`
  + EXPLAIN verification (schema-inspected 3/3, own probes in all
  traces) and re-derived the diagnosis independently — the artifact
  names `MISSING INDEX: orders.user_id` verbatim, and C runs confirmed
  it from the live DB rather than trusting the file. C was nominally
  the fastest arm (27.7s vs A's 36.3s; 3.0 vs 3.3 Bash calls) —
  within noise at n=3, reported not interpreted.
- **All 9 runs behaved identically at the task level**: diagnosed the
  un-indexed `orders.user_id` FK, proposed `CREATE INDEX` on it (5/9
  chose a composite `(user_id, placed_at)` or `(user_id, placed_at,
  status)` and argued the leading column covers the FK — including all
  of A), verified with `EXPLAIN QUERY PLAN` before/after on a `$TMPDIR`
  copy of app.db (9/9), and concluded no query-file rewrite was needed
  ("files touched: none", or only DBMAP.md in B). The task-correct
  grader's no-op-note clause scored all of these PASS as designed.
- **Headless usability: clean.** No run in B (or the pilot) stalled on
  the skill's interactive connection question — the prompt's
  single-connection steering pre-answers it. The skill's two follow-up
  questions ("apply the migration?" / "CLAUDE.md rule?") appeared in
  final replies 4/4 B-form runs, asked in-band rather than blocking —
  the intended headless behavior. Recorded as the plan's
  headless-usability observation: no finding against the skill.
- Ballast held: 0/9 runs touched `app/models/`, `scripts/`, `.env`, or
  any unrelated table's DDL (no-wrong-edits 9/9 with zero judge
  push-back).

## Cost

$0.714 (pilot command, incl. the $0.335 ablation-default baseline) +
$0.659 + $1.032 + $0.729 (arms) = **$3.13 of the $12 budget**; priciest
single run $0.368 (B run 0, ≪ the $1.50 abort line); no command neared
its $4 cap.

## Disposition (pilot language only)

Null at this scale, by ceiling: this model+harness diagnoses an
un-indexed FK cold in ~4 turns, so /dbmap neither helps nor hurts
graded correctness here — running it first costs ~2× turns and ~1.5×
dollars; a silently pre-injected DBMAP.md IS read (unlike REPOMAP.md)
but is re-verified rather than trusted, buying nothing measurable. The
repomap experiment's follow-up direction (a POINTED map — prompt or
CLAUDE.md rule) is half-answered here: even an actually-read map that
names the answer gets re-derived. Any future retest needs difficulty
headroom, not map prominence: a larger/obfuscated schema, no sqlite3
CLI on PATH, or a cheaper baseline model. The case, artifact, fixture
and graders stay as a permanent fixture; the corrected grader set
(no Edit-proof; diagnosis llm + schema-inspected indicator) produced
zero false FAILs across 9 runs and is reusable as-is.
