# Context-map utility — consolidated verdict (2026-10-06)

Consolidates the two three-arm experiments that asked, for /repomap and
/dbmap: **do context maps help the agent work/program better?**

- repomap: [`2026-10-06-repomap-utility.md`](2026-10-06-repomap-utility.md)
  (PREREG `053ae12`, runs `20fa0ab`)
- dbmap: [`2026-10-06-dbmap-utility.md`](2026-10-06-dbmap-utility.md)
  (PREREG `bd83eaa`, runs `ffb6ee8`)

Design (both): arms **A** cold · **B** skill-first (the "run it first"
policy, one extra prompt line) · **C** map pre-injected (map value with
the call overhead removed). n=3/arm, judge `sonnet`, primary endpoint =
mean(task-correct, no-wrong-edits), pre-registered ±0.34 signal rule,
skill-fired ≥ 2/3 in arm B as the power gate (both passed 3/3), and the
single-plugin check clean on every command (all runs from the PREREG-
registered git-less `/tmp/superskills-eval-copy`).

## Verdict table

The outcome matrix was fixed in advance, identically in both PREREGs:

> B>A ∧ C≈B → "run it first" justified · C>A ∧ B≈A → prefer pre-generated
> maps over on-demand runs · **B≡A≡C → null at this scale.**

Both experiments landed on the third row — the null row — and it is the
only row either could honestly claim:

| experiment | case | skill-fired (B) | primary A / B / C | Δ(B−A) | Δ(C−A) | matrix row | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| repomap | `repomap-nav-task` | 3/3 powered | 0.333 / 0.333 / 0.667 | 0.000 | +0.333 (< +0.34) | **B≡A≡C** | **null at this scale** |
| dbmap | `dbmap-schema-task` | 3/3 powered | 1.000 / 1.000 / 1.000 | 0.000 | 0.000 | **B≡A≡C** | **null at this scale, by ceiling** |

Same row, different mechanisms (this distinction is the finding):

- **repomap — null by non-discovery.** Arm C's pre-injected REPOMAP.md
  was opened **0/3**: a prompt-unmentioned ambient map is invisible, so
  C was behaviorally arm A plus an unread file. Its +0.333 sits one
  grader-run short of the +0.34 signal line and cannot be map value.
- **dbmap — null by ceiling.** Arm A's cold runs already solve the task
  perfectly (~4 turns, two sqlite3 commands), so the map has no
  correctness headroom. C **did** read the map 3/3 (a root-level
  DBMAP.md is swept into the opening look at the repo) — and still
  re-derived the diagnosis from the live DB in every run rather than
  trusting the file, even though it names `MISSING INDEX: orders.user_id`
  verbatim.

## Cross-experiment pattern — three honest takeaways

1. **No signal that maps help at this fixture scale.** Neither
   experiment's |Δ| reached +0.34 on the primary endpoint in either
   comparison; no n=5 confirmatory is licensed by the PREREGs.
2. **The two nulls have different mechanisms.** One is a discovery
   failure (the map is never found when ambient), the other a relevance
   failure (the map is found and read, but the task is easy enough that
   it is redundant). Any follow-up must say which failure it is
   attacking, because they need opposite fixes.
3. **The only directional signal anywhere is a cost.** dbmap's B arm
   paid ~2× turns (4.3→9.0), +38% duration, +57% per-run cost
   ($0.344 vs $0.220) for zero correctness gain; repomap's B arm showed
   the same non-gain (Δ(B−A)=0.000) with turns 5.7→12.0 (~2.1×) and
   +$0.13/arm. The **"run it first" policy has measured costs and no
   measured benefit at this scale** in both experiments.

## Exploration cost per arm

Secondary metrics, reported not gated (exploration is Bash-carried in
this harness/model — the Read/Grep/Glob tool counts read ~0 across all
18 runs; out-of-fixture reads: 0 in all 18 runs):

| metric (mean, n=3) | repomap A | repomap B | repomap C | dbmap A | dbmap B | dbmap C |
| --- | --- | --- | --- | --- | --- | --- |
| turns | 5.7 | **12.0** | 7.0 | 4.3 | **9.0** | 4.0 |
| durationSeconds | 46.3 | 54.3 | 48.7 | 36.3 | 50.3 | 27.7 |
| Bash calls | 4.7 | 6.0 | 3.7 | 3.3 | 6.0 | 3.0 |
| cost per arm | $0.846 | $0.977 | $0.849 | $0.659 | $1.032 | $0.729 |

Both B arms roughly double the turns for the map detour; both C arms
sit at or below their A arm (dbmap's C was nominally fastest — 27.7s vs
36.3s — within noise at n=3, reported not interpreted).

## Spend vs plan budget

| experiment | pilots | arms | total |
| --- | --- | --- | --- |
| repomap | $0.625 (2 pilots) | $2.672 | $3.30 |
| dbmap | $0.714 (incl. the unregistered $0.335 ablation-default baseline) | $2.420 | $3.13 |
| **plan total** | | | **$6.43 of ≤$25** |

Every command capped `--max-cost-usd 4` (pilots 2); priciest single run
$0.368 — far below the $1.50 abort line; no command neared its cap.

## graphify: scoped out

graphify's output is human-facing HTML; no agent-side consumer of a
graphviz-style map exists in this codebase, so there is nothing for a
utility experiment to measure. Revisit only if an agent consumer lands.

## Follow-up candidates, gated on the verdicts

The brief's original gates — "run /dbmap first" ONLY if B>A; the
CLAUDE.md map-rule ONLY if C>A with B≡A — **neither fired**. What the
verdicts actually license:

1. **A harder-fixture retest (the only open candidate).** Both nulls
   were mechanism-limited, one by discovery and one by ceiling, so a
   retest is worth spending only if it fixes both at once: an obfuscated
   schema AND a task where navigation genuinely binds (difficulty
   headroom, so the map has room to matter), plus the discovery problem
   arm C exposed fixed — e.g. a CLAUDE.md pointer that makes the map
   load-bearing rather than ambient. At n=5, per the PREREGs'
   confirmatory language.
2. **The CLAUDE.md map-rule (dbmap already offers it) — NOT justified
   by these nulls.** The trigger (C>A with B≡A) did not fire, and the
   mechanism argues against it: dbmap's arm C read the map 3/3 once
   discoverable and ignored it anyway, re-deriving from the live DB.
   Prominence was not the binding constraint; difficulty was.
3. **No "run it first" convention.** Actively contradicted by the cost
   signal: measured ~2× turns / +57% per-run in dbmap and the same
   non-gain with 5.7→12.0 turns in repomap, against zero measured
   correctness benefit in either.

Unaffected elsewhere: write-plan's utility-ask under-firing is a
separate case (`writeplan-test-strategy`) untouched by these
experiments.

## What stays

Both fixtures, cases, committed artifacts and grader sets stay as
permanent eval assets (registered in RUBRIC.md's sampling table).
Known warts for reuse, from the repomap report: the task-correct
grader's self-referential edit-proofs clause and the edits-made
grader's Edit-tool-only pattern (this model edits via Bash/Write) —
dbmap's corrected grader set (diagnosis llm + schema-inspected
indicator, no Edit-proof) produced zero false FAILs across 9 runs and
is reusable as-is.

No VERSION bump: this plan ships measurements only; any skill-body
change its verdicts might justify is a separate eval-gated plan.
