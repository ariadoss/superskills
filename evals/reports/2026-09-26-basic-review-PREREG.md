# Pre-registration: does /basic-review help or hurt, and does gstack's checklist add value?

Written 2026-09-26, before any run.

## Question

When gstack's `/review` is unavailable, `/qa-full` and `/daily-qa` now fall back
to the in-tree `/basic-review`. Does that fallback find more real bugs than an
agent asked to "review the pending changes" with no skill, without adding false
blockers? And does adding gstack's pre-landing checklist to `/basic-review`
improve it further?

## Arms

- **A, no skill:** "review the pending changes and report issues that should block merge."
- **B, /basic-review v1:** `skills/basic-review/SKILL.md` at commit 4b1b25d.
- **C, /basic-review + checklist:** B plus a local copy of gstack's
  `review/checklist.md` (gstack 1.80.0.0, MIT), applied as Pass 1, Pass 2 and
  its Suppressions list.

Each run is an in-session Sonnet `general-purpose` subagent, working read-only
in its own copy of a fixture repo. B and C read the skill from a path and follow
it; the skill is not installed, so there is no routing step to measure.

## Fixtures

Seven small repos, each with a `main` branch and a `feature` branch whose one
commit is the change under review. There are no hint comments in the code.

| Fixture | Planted bugs | Category |
|---|---|---|
| F1 pagination | off-by-one page start; `except Exception: return []` swallows a corrupt store | correctness; reliability |
| F2 orders endpoint | SQL built by string concatenation of a URL param; no ownership check (sibling route has one) | security; security |
| F3 sync worker | retry loop with no backoff or limit; list membership dedupe over ~500k records | reliability; performance |
| F4 http client | default timeout silently changed from 30 s to none; payload key renamed while two in-repo consumers read the old key | contract; contract |
| F5 refactor | none (clean control; decoy pairwise loop) | none |
| F6 --dry-run | none (clean control) | none |
| F7 refunds | new enum value makes an existing `invoice_label` outside the diff raise | correctness (enum completeness) |

Nine planted bugs in total. Two runs per arm per fixture: 42 runs, 18 planted-bug
opportunities per arm.

## Grading

- A planted bug is **found** when the report cites its file within ±5 lines
  (or names the function) and states the defect. Mentioning the line without
  the defect is not found.
- Every other finding is open-coded as a **real extra issue** (I would also
  block or fix it), a **nit** (true but not merge-blocking), or **false** (the
  claim is wrong). A **false blocker** is a false or nit finding labelled
  CRITICAL or HIGH (arm A: labelled blocking or equivalent).
- Clean fixtures (F5, F6) pass when the run raises no false blocker.

## Decision rules (fixed now)

1. **basic-review helps** if B or C finds at least 2 more planted-bug instances
   than A (pooled over 18) without more than 1 extra false blocker. **It hurts**
   if both B and C find at least 2 fewer, or raise at least 2 more false
   blockers. Anything else is **no measurable difference**, reported as such.
2. **Adopt the checklist (C)** if C finds at least as many planted-bug instances
   as B and raises no more than 1 extra false blocker. Otherwise keep B.
3. F7 is reported separately: it is the case the checklist's "enum
   completeness" section targets.

Small n: these are directional results on seeded bugs, not production rates.
