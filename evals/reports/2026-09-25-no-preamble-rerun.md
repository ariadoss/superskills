# No-preamble rerun: the invocation floor is the harness, not the prompt (2026-09-25)

Follow-up to [`2026-09-25-waza-negative-scope.md`](2026-09-25-waza-negative-scope.md).
Pre-registration, written before the rerun:
[`2026-09-25-no-preamble-PREREG.md`](2026-09-25-no-preamble-PREREG.md).

**Outcome: the pre-registered "stop" branch fired.** Removing the suppressive
clause moved invocation from 22% to 26%, inside the <=30% band that was defined
in advance to mean the floor belongs to the harness. In-session subagent evals
should not be used for routing questions. Separately, the higher-firing arm still
produced **zero** false triggers, which is the first non-artifactual support for
the earlier decision not to import Waza's negative-scope clause.

## The manipulation

One clause removed from all 15 case prompts, nothing else changed:

> Keep it tight: do the core of the request, and if it would turn into a long
> end-to-end pipeline, outline the remaining steps instead of running them all.

Verified mechanically rather than by eye: across the 30 paired prompts, the two
arms are byte-identical once that clause is stripped (30/30), the clause is
present in 45/45 baseline prompts and 0/45 rerun prompts.

## Results, 45 runs per arm

| Metric | With clause | Clause removed |
|---|---|---|
| Runs firing any owned skill | 10 / 45 (22%) | 12 / 45 (26%) |
| TP — intended skill fired | 10 / 42 | 12 / 42 |
| TPR (recall) | 0.238 | 0.286 |
| **FP — a wrong owned skill fired** | **0** | **0** |
| TNR (neighbour-scoped) | 1.000 (TN=114) | 1.000 (TN=114) |
| Precision | 1.000 | 1.000 |

The +2 runs are noise at this n: 10/45 versus 12/45 is z≈0.5, p≈0.6. Per-skill
movement is equally small — `clean-code` 2→4, `iac-scan` 2→3, `perf-profile`
1→0, `qa-full` 3→3.

**Q1, as decided in advance:** invocation <=30%, so the floor is the harness.
My preamble was a real confound and worth removing, but it was not the cause.
The 2026-09-24 report's comparison (4/12 in-session versus 12/12 under `claude
plugin eval`, on cases carrying no such preamble) pointed the same way. Prediction
1 in the prereg said 30-45%; that was wrong, and wrong in the direction of my
own hypothesis.

**Q2, the one that mattered more:** FP stayed at 0 across both arms and 228
neighbour-scoped negatives. A suite that fires more often still found nothing for
a `Not for <neighbour>` clause to repair. That is weak-but-real evidence, where
the baseline's FP=0 alone was close to vacuous. Prediction 2 (at most one or two
FPs, most likely on B2) also did not happen.

## The finding that survived both arms

Six owned skills fired in **zero** of their 36 combined attempts: `debug`,
`verify`, `test-coverage`, `db-optimize`, `web-perf`, `defense`. This is stable
across a prompt manipulation that moved everything else, so it is not a wording
artifact.

`verify` is the clearest case and it is not a routing problem at all. In all six
runs the agent ran the suite by hand, read the failure, and reported the root
cause correctly — which is exactly what `verify`'s description asks for ("requires
running verification commands and confirming output before making any success
claims"). The skill describes behaviour the model already exhibits by default, so
there is nothing for the router to gain by loading it. Prediction 3 (that `debug`
and `verify` would stay near zero) held, though for a different reason than the
"thin description" I guessed: `test-coverage` and `db-optimize` have rich
descriptions and also went 0/6.

## Two grader bugs found while doing this, both now tested

Worth recording because each would have inverted a conclusion:

1. **Spawned subagents counted as runs.** A fan-out skill launches its own
   subagents, and each child's prompt repeats the fixture path. One rerun case
   appeared as 10 transcripts, inflating n to 46 and filing children's behaviour
   against the parent (`daily-qa` showed 6 attempts where 3 exist). A run is now
   only a transcript carrying the launcher's marker sentence.
2. **A shell completion check that matched prose.** `grep -q SubagentHandback`
   over a raw transcript matches the string in ordinary text, so three
   still-running `qa-full` runs looked finished and were briefly graded as
   "no skill fired". Completion has to be a `SubagentHandback` *tool_use*.

Both have regression tests in `tests/routing-eval.bats` (10 tests).

## Cost

~3.5M subagent tokens for this arm (most runs ~50k; the four full-pipeline
`qa-full`/`daily-qa` runs ran 128k-226k each), ~6.7M across both arms. All
in-session and plan-covered; no billed command was run. Removing the brevity
clause did **not** blow up cost the way the prereg expected — the fixture is
small, so the ceiling was the fixture, not the instruction.

## What to do with this

- **Do not run another in-session routing eval.** The ceiling is ~25% invocation
  regardless of prompt wording, and a suite that fires that rarely cannot
  discriminate a description edit. Recorded in `evals/README.md`.
- **Descriptions are not where routing precision is lost.** 0 false triggers in
  90 runs across two prompt conditions. Stop looking there.
- **The open question is invocation, and it needs a different instrument.** The
  one free lead worth pulling is `verify`: if a skill's description restates
  default model behaviour, the router has no reason to load it, and that is a
  skill-design question answerable by reading, not by another 6M-token eval.
