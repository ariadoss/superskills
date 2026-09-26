# Waza review: negative scope in skill descriptions — baseline eval (2026-09-25)

Prompted by "anything useful we can take from [tw93/Waza](https://github.com/tw93/Waza)?",
with the condition that any change be gated on a before/after eval.

**Outcome: no skill descriptions were changed.** The baseline found zero false
triggers, so the one Waza mechanism worth testing had nothing to fix, and the
pre-registered pass rule's precondition failed. The second arm was not run.
Pre-registration: [`2026-09-25-waza-negative-scope-PREREG.md`](2026-09-25-waza-negative-scope-PREREG.md),
written before any edit.

## What Waza does differently

Every Waza skill's `description` ends with an explicit negative clause:

```yaml
description: "Finds root cause before any fix. Use when something errors, crashes,
  regresses, or used to work. Not for code review or new features."
```

Shape: `<what it does>. Use when <triggers>. Not for <the adjacent skill's job>.`
It is the only Waza mechanism that reaches the model at routing time, so it was
the only one worth an eval. Measured here: **2 of 43** owned `skills/*/SKILL.md`
descriptions carry any negative scope (`clean-code`, `superskills-doctor`).

Worth recording: `ENGINEERING_STANDARDS.md` already requires this ("the
`description` says when to fire *and* names the neighbouring skill it must not be
confused with"). The corpus does not follow its own standard. The question the
eval answers is whether that non-compliance costs anything measurable.

## Instrument

In-session Sonnet `general-purpose` subagents (covered by the plan; `claude
plugin eval` is off the table per the no-Claude-credits rule). 15 cases across 5
confusable clusters, n=3, each run in its own throwaway fixture repo so
concurrent agents could not contaminate each other.

Fixture: `_lib/qa-full-fixture.sh` (failing test, hardcoded secret, SQL
injection, N+1, inaccessible form, root Dockerfile, local bare origin) plus the
new `_lib/routing-fixture-extra.sh` (duplicated tax logic, a quadratic hot path,
a render-blocking HTML page, a `pull_request_target` CI workflow). Graded by the
new `_lib/grade-routing.py` from each subagent's JSONL transcript: which skills
were loaded via the Skill tool, and what the handback report named.

## Results (all 45 pre-registered runs complete)

| Metric | Baseline |
|---|---|
| Runs firing any owned skill | 10 / 45 (22%) |
| TP — intended skill fired | 10 / 42 |
| FN — intended skill missed | 32 / 42 |
| **FP — a wrong owned skill fired** | **0** |
| TPR (recall) | 0.238 |
| TNR, neighbour-scoped | 1.000 (TN=114, FP=0) |
| Precision | 1.000 |
| Accuracy (intended fired) | 0.222 |

Per skill, TP / attempts: `qa-full` 3/6, `clean-code` 2/6, `iac-scan` 2/6,
`daily-qa` 2/3, `perf-profile` 1/3. **Zero in every run:** `debug`, `verify`,
`test-coverage`, `db-optimize`, `web-perf`, `defense`. No skill fired on a case
it was not intended for, in any of the 45 runs.

TNR is reported neighbour-scoped — each case's negatives are its cluster peers
(A1's are `test-coverage`, `verify`, `tdd`) — because pooling over all 43 owned
skills builds a denominator mostly from skills no request could have matched.

**One grader correction worth recording.** The first pass scored C3-r1 as two
false positives: it fired `clean-code` and `iac-scan` on a `qa-full` case. That
was the grader being wrong, not the router. `skills/qa-full/SKILL.md` explicitly
instructs invoking `/clean-code` (Step 3) and `/iac-scan` — the fan-out is the
pipeline working. `grade-routing.py` now derives each orchestrator's documented
fan-out from its own SKILL.md and excludes it from FP scoring. Without that fix
this report would have claimed a false trigger that does not exist. C3-r3 is the
case that proves the rule matters: it is the one run where the pipeline executed
as designed, firing `qa-full` plus six documented sub-skills (`/review`,
`/clean-code`, `/defense`, `/iac-scan`, `/db-optimize`, `/a11y`,
`/test-coverage`). Scored naively that single run would have invented six false
positives and inverted this report's conclusion.

## Pass rule, as written before the edit

> Keep the edits only if ALL hold, pooled per arm over 45 runs:
> 1. **TNR up:** pooled FP count after <= before.
> 2. **TPR held:** pooled TP count after >= before - 1.
> 3. **No new confusion:** no owned skill gains an FP on a case where it had zero FPs in the baseline.
> 4. **Per-skill floor:** no edited skill's TP count drops to 0 when it was non-zero in the baseline.
>
> A clause is written **only** for a confusion observed in the baseline;
> hypothetical overlaps get no clause.

Baseline FP = 0 across all 45 runs, so no confusion was observed, so no clause is justified for any
skill. Rule 1 cannot improve on zero and rules 3-4 can only be broken. This is
the pre-registered outcome, not a deviation.

### What FP=0 does and does not license

It licenses: *this suite found no confusion for a boundary clause to repair, so
there is no measured defect here and no basis to edit 41 descriptions.* It does
**not** license "the clause is worthless in production". Recall was 0.238, just
above the pre-registered 20% degeneracy floor, and a suite that barely fires
cannot prove a precision change is absent — only that it did not show up here.
The two claims have to stay separate.

## Why trigger-phrase enrichment was also ruled out

The obvious pivot — if recall is the problem, add more trigger phrasings, which
Waza also does heavily via `when_to_use` — is contradicted by these same runs.
The router had the exact phrase and declined anyway:

| Case prompt | Description already contains | Fired? |
|---|---|---|
| "Is this branch ready to ship?" | `"is this ready to ship"` (qa-full) | 0/3 |
| "Write the missing edge-case tests" | `"write missing tests"`, `"cover edge cases"` (test-coverage) | 0/3 |
| "Find the N+1s" | `"check for N+1"` (db-optimize) | 0/3 |
| "DRY it up" | `"DRY this up"` (clean-code) | 0/3 |

Failures do not correlate with description length either: `debug` (91 chars) and
`qa-full` (585 chars) miss alike, while `iac-scan` fired twice. More phrases
cannot fix a router that already matched the phrase and chose to work directly.

## What 0.135 recall actually measures — the instrument, not production

Two causes are visible and both are instrument artifacts:

1. **In-session subagents under-fire.** `reports/2026-09-24-description-trim.md`
   already measured this: `superskills-doctor` fired 4/12 in-session versus 12/12
   under `claude plugin eval`.
2. **My own preamble suppressed it.** Every case prompt said "if it would turn
   into a long end-to-end pipeline, outline the remaining steps instead of
   running them all" — a direct instruction against loading `qa-full`, whose
   description *is* a long pipeline. C1-r1 reported "did not spin up any pipeline
   beyond that"; C2-r1 listed four sub-skills it chose not to invoke. The
   preamble was added to bound token cost and was identical in both planned
   arms, so it would not have biased a before/after comparison — but it means
   0.238 is this instrument's floor, not a production recall estimate. The two
   long `qa-full` runs said so outright: C3-r1 reported doing the work directly
   "instead of invoking each qa-full sub-skill separately via the Skill tool,
   per your 'keep it tight' instruction", and C3-r2 the same. Those runs are also
   what lifted firing to 22%; the metric moved from 0.135 to 0.238
   once the three of them landed.

**Update, same day: the preamble was tested and was not the cause.**
[`2026-09-25-no-preamble-rerun.md`](2026-09-25-no-preamble-rerun.md) re-ran all 45
cases with that clause removed and nothing else changed. Invocation went 22% ->
26%, noise at this n (z≈0.5). The ceiling is the harness, not my wording, so the
0.238 above is close to this instrument's real ceiling rather than a
self-inflicted floor, and this confound was smaller than the paragraph above
first implied. The rerun also held FP at 0 in both arms, which upgrades the
verdict below from "no defect observed in a suite that barely fires" to "no
defect observed across two prompt conditions, 90 runs, 228 neighbour-scoped
negatives".

**Third confound, found while grading: our own Stop hook re-entered two runs.**
`scripts/lib/qa-full-ledger-lib.sh`'s `qfl_report_path` prefers a report the
session wrote and otherwise falls back to the newest file in
`$cwd/qa-full-reports/`. A subagent's cwd is this repo, not the fixture, so when
C3-r2 invoked `/qa-full` without writing a report file, the hook resolved against
this repo's stale `qa-full-reports/main-2026-09-19.md` and sent the agent back to
justify a six-day-old ledger. C3-r1 was re-entered the same way and loaded
`/clean-code` and `/iac-scan` in that extra turn. `grade-routing.py` now stops
counting at the first `SubagentHandback`, so hook-induced skill loads are
excluded from the routing decision under test. Reported to the maintainer as its
own defect; not fixed here, because the fix is a design call (scope the lookup to
the transcript's declared project root, or refuse when the session wrote no
report).

Supporting evidence that descriptions do reach the router: agents repeatedly
named skills they never loaded. B3-r2's report routed its own out-of-scope
findings to `/security-review`, `/cso`, `/db-optimize`, `/iac-scan`, `/web-perf`,
`/a11y` and `/debug` by name without invoking any of them.

Counted across the suite: **22 of 45 runs named a `/skill` they never loaded**
(67 mentions), against 10 runs that actually invoked one. Awareness is not the
bottleneck; invocation is.

## Verdict on each Waza idea

| Idea | Verdict |
|---|---|
| `Not for <neighbour>` in `description` | **Measured, not imported.** FP=0/45 — no false trigger *observed* to fix (this instrument cannot rule out a production effect). Already required by `ENGINEERING_STANDARDS.md` anyway. |
| Dense trigger-phrase lists (`when_to_use`) | **Contraindicated** by the table above. |
| `when_to_use` / `dispatch_intent` frontmatter | **Skip.** Neither is a documented Claude Code frontmatter field, and `description` is what the router matches on. Not a compatibility risk: `vendor/gstack/*/SKILL.md` already ships extra keys (`preamble-tier`, `version`) and no test in this repo rejects unknown ones — the reason to skip is that it duplicates `description` without reaching the router. |
| `RESOLVER.md` routing table with numbered tie-breaks | **Maintainer doc only.** Nothing reads it at runtime, so it cannot move TPR/TNR. |
| Latent-vs-deterministic (skill vs script) rule | **Taken** into `ENGINEERING_STANDARDS.md`. Not a routing change, so this eval does not apply to it. |
| `check_doc_refs.py` dead-reference linter | **Skip the linter, keep the findings.** 8 of 11 hits on this repo were false positives (refs resolving at repo root, or naming an upstream repo's files). Three are real, all in Alignify-imported marketing skills: `strategies/structure/website-structure` → `docs/skills-reference.md`, `strategies/structure/seo` → `templates/project-task-tracker.md`, `channels/community/directory-submission` → `templates/project-context.md`. Fixing them means fetching the upstream companion files — a separate task. |
| `scan_skill_security.py`, `block-pipe-to-shell.py` | **Skip.** Aimed at auditing third-party skills; ours are our own. |

## Reusable output

- `_lib/routing-fixture-extra.sh` — the four triggers `qa-full-fixture.sh` lacks.
- `tests/routing-eval.bats` — 9 tests over both, including regressions for the
  three grader bugs below.
- `_lib/grade-routing.py` — confusion matrix, neighbour-scoped TNR, awareness
  proxy, handback-gating so a still-running transcript is never scored as "no
  skill fired" (it was, before the gate was added), and fan-out awareness so an
  orchestrator's own sub-skills are not counted against it.

## Cost

~3.2M subagent tokens for 45 runs: most ran ~50k, while the three full-pipeline
`qa-full` runs took 160k-210k each. All in-session and plan-covered.
No Claude credits beyond plan; no billed eval command was run.
