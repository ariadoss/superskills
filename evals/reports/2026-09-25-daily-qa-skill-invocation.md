# Does /daily-qa invoke its sub-skills? (2026-09-25)

Follow-up to `2026-09-24-qa-full-skill-invocation.md`, same method.

## Method

- Fixture: `evals/_lib/daily-qa-fixture.sh`. The qa-full fixture reshaped for a
  daily sweep: base commit backdated ten days, the planted commit (failing
  test, Stripe-format key, SQL injection, N+1, inaccessible `.tsx` form, root
  Dockerfile) fast-forwarded onto `main`, so only it is inside the 24h window.
- Runner: in-session Sonnet `general-purpose` subagents, prompt
  "Run /daily-qa on this repo." Three baseline runs on unchanged daily-qa,
  then three after the edits.
- Graded from transcripts with `scripts/lib/qa-full-ledger-lib.sh`
  (`qfl_invoked_skills`) plus checks on the report and the fixture's git state.
  Expected auto-runs on this fixture: `/code-review`, `/defense`,
  `/db-optimize`, `/iac-scan`.

## Baseline

daily-qa did **not** have qa-full's problem: all four auto-run sub-skills were
invoked with the Skill tool in every run (12/12). Every report caught the
failing test, the SQL injection, the secret and the N+1; no run committed or
edited source (the only tracked change is the `.gitignore` line the skill asks
for).

A plausible reason qa-full drifted and daily-qa didn't: daily-qa is report-only
with four sub-skills, qa-full is fix-and-verify with about ten and a long
fix loop, so hand-doing checks is more tempting there.

What the baseline did show is a `/code-review` problem:

- `/code-review` **is** invocable from a session. It runs as a background
  task. qa-full's SKILL.md said Claude Code built-ins "can't be invoked from
  inside a session"; that sentence is corrected.
- The task starts in the session's working directory. Run b1 first reviewed
  the superskills repo instead of the fixture until it passed the path.
- The report can be written before the task returns. Run b2 wrote §2 by hand
  (and said so).

## Edits (v2.25.1)

- daily-qa Step 3: pass the repo's absolute path and the commit range to
  `/code-review`; wait for its result before writing §2; if it has not
  returned, write §2 as pending with the fallback scan labeled as such.
- daily-qa `allowed-tools`: add `Skill` (same gap qa-full had).
- qa-full Step 3: drop the "can't be invoked" claim.

## Results

| | Baseline | After |
|---|---|---|
| Auto-run sub-skills invoked | 12/12 | 12/12 |
| First `/code-review` call names the target repo | 1/3 | **3/3** |
| §2 built from `/code-review` output | 2/3 | 2/3 |
| §2 honest about its source when `/code-review` did not return | 1/1 | 1/1 |
| All five planted problems in the report | 2/3 (root container missed) | 2/3 (root container missed) |
| Commits or source edits | 0 | 0 |
| Subagent tokens per run | 104k, 116k, 97k | 131k, 80k, 97k |

## Reading

- The targeting fix worked: 1/3 to 3/3.
- The wait fix could not be tested fairly in this setup. `/code-review`'s
  internal finder agents reported to the top-level session, not to the eval
  subagent that invoked it, so in two of six runs the result never reached the
  report. In a normal session where the user types `/daily-qa`, the result
  returns to that session. The after-run that missed it labeled §2 as the
  fallback, as the new rule asks.
- The root-container miss (one run per arm) is `/iac-scan` detection variance,
  not a daily-qa instruction problem; not fixed here.
- n = 3 per arm, one fixture.
