# Pre-registration: no-preamble rerun (2026-09-25)

Written **before** the rerun. Follow-up to
[`2026-09-25-waza-negative-scope.md`](2026-09-25-waza-negative-scope.md), whose
baseline hit a 22% skill-invocation floor and so could not discriminate a
`description` edit.

## The manipulation

Exactly one clause is removed from all 15 case prompts. Nothing else changes:
same cases, same n=3, same Sonnet `general-purpose` subagents, same fixture
builders, same grader.

Removed:

> Keep it tight: do the core of the request, and if it would turn into a long
> end-to-end pipeline, outline the remaining steps instead of running them all.

Kept verbatim (it locates the work, it does not discourage skills):

> Your project root for this task is <dir> — a small Node project, currently on
> branch feature/checkout. Work there; ignore the directory this session started in.

Arm label `nopre` (fixtures `runs/nopre-<CASE>-r<N>`), graded with
`grade-routing.py <tasks> skills nopre`.

## Why it was confounded

That clause is an instruction against loading `/qa-full`, whose description *is*
a long end-to-end pipeline. Two baseline runs said so outright: C3-r1 reported
working directly "instead of invoking each qa-full sub-skill separately via the
Skill tool, per your 'keep it tight' instruction". It was identical across both
planned arms of the original A/B, so it could not have biased that comparison,
but it caps absolute invocation and therefore the whole suite's sensitivity.

## Two questions, decided in advance

**Q1 — is the floor mine or the harness's?**

- Invocation rises to **>= 40%** (18+/45): the floor was largely my prompt.
  In-session routing evals are usable once it is dropped, and description work
  can be revisited on an instrument that can actually see a change.
- Invocation stays **<= 30%** (13-/45): the floor is the harness, not the
  preamble. In-session subagents under-invoke regardless of prompt wording, so
  **stop using this method for routing questions** and say so in
  `evals/README.md`. A decisive negative, and the cheapest possible way to
  learn it.
- 31-39%: partial. Report as inconclusive; do not round it into either story.

**Q2 — does a higher-firing arm expose misroutes?** This matters more than Q1,
because it is the real test of Waza's clause. The baseline's FP=0 is weak
evidence: a suite that rarely fires rarely mis-fires.

- **FP > 0**: Waza's negative-scope clause has a measured target after all.
  That **reopens** the negative-scope question, and the fix is to write the
  clause for the specific confusions observed, then re-run this arm as the
  before. The earlier "not imported" verdict would be superseded, not defended.
- **FP = 0 at >= 40% invocation**: our descriptions genuinely do not misroute at
  a firing rate where they could have. That is the first real support for the
  original verdict, rather than an artifact.

## Predictions, recorded so they can be wrong

1. Invocation rises but less than hoped: **30-45%**. The 2026-09-24 report saw
   4/12 in-session versus 12/12 under `claude plugin eval` on cases that had no
   such preamble at all, so a harness component clearly exists independent of my
   prompt.
2. FP stays 0 or shows at most one or two, most likely `qa-full` or `clean-code`
   appearing on `B2` ("review the changes for bugs"), the one case whose intended
   target is a non-owned skill.
3. `debug` and `verify` stay at or near zero. Both have thin, abstract
   descriptions ("Use when encountering any bug..."), and neither names a
   concrete artifact the way `iac-scan` does.

## Cost, and the stop rule

The brevity clause was what bounded cost. Removing it means more full-pipeline
runs; the three that fanned out in the baseline cost 160k-210k tokens each
against ~50k for the rest. Expect roughly **5-8M subagent tokens**, against
~3.2M for the baseline. All in-session and plan-covered; no billed command is
involved. If wave one alone exceeds ~4M, stop and report on n=15 rather than
spending the rest.

The `/qa-full` ledger Stop hook will re-enter more runs than before (it resolves
against this repo's stale `qa-full-reports/`). `grade-routing.py` stops counting
at the first `SubagentHandback`, so hook-induced loads stay out of the measured
routing decision.
