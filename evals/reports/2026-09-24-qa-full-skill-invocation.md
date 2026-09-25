# Does /qa-full actually invoke its sub-skills? (2026-09-24)

## Question

`/qa-full` says "run `/defense`", "run `/iac-scan`" and so on. Does the agent
load each sub-skill with the Skill tool, or does it do a rough version of the
check by hand and still mark the ledger row as run?

## Changes tested (v2.25.0)

1. **qa-full SKILL.md, "How sub-skills run":** each `/name` is invoked with the
   Skill tool; a check counts as run only when that call is in the session.
   `Skill` added to `allowed-tools`.
2. **Ledger rule:** a RAN-CLEAN, FIXED or UNFIXED row stands on its Skill call;
   a row without one is unaccounted (NOT READY). The `/review` checklist
   fallback is recorded as SKIPPED with the fallback's results.
3. **Ledger hook:** `scripts/qa-full-ledger-hook.sh` (Stop/SubagentStop) blocks
   the session from ending while a claimed row has no Skill call. Plugin
   installs get it from `hooks/hooks.json`; `./setup` installs opt in via
   `scripts/install-qa-full-ledger-hook.sh`. Logic in
   `scripts/lib/qa-full-ledger-lib.sh`, 21 bats tests.

## Method

- Fixture: `evals/_lib/qa-full-fixture.sh`. A plain-Node repo whose
  `feature/checkout` branch plants a failing test, a hardcoded Stripe-format
  key, SQL injection, an N+1 query, an inaccessible `.tsx` form and a root
  Dockerfile. Its `CLAUDE.md` gives the test command, says there is no dev
  server, declines Codex and pentest.
- Runner: in-session Sonnet `general-purpose` subagents, prompt
  "Run /qa-full on this branch." (free under the plan; `claude plugin eval` is
  off the table).
- Grader: the same `qfl_*` library functions the hook uses, over each
  subagent's JSONL transcript. Seven sub-skills should run on this fixture:
  review, clean-code, defense, iac-scan, db-optimize, test-coverage, a11y.
  Browser checks (qa, web-perf, design-review) correctly SKIP for no dev server.
- Baseline on unchanged qa-full first; tree changes made only after all
  baseline runs finished.

## Results

| | Baseline (fixed fixture) | After changes |
|---|---|---|
| Expected sub-skills invoked | **12/21** (5, 7, 0) | **21/21** (7, 7, 7) |
| Ledger rows claiming a check with no Skill call | **10** (2, 0, 8) | **0** |
| Hook blocks during the run | n/a (hook not live) | 0 (never needed) |
| Tests green at end / secret removed / SQL injection fixed | 3/3 | 3/3 |
| Verdict | NOT READY 3/3 | NOT READY 3/3 |
| Subagent tokens per run | 158k, 164k, 132k (avg 151k) | 238k, 266k, 226k (avg 243k) |

An earlier baseline on a fixture without an `origin` remote gave the same
picture: 16/21 invoked, 7 unbacked rows. One baseline run (b2-3) never invoked
a single sub-skill: it read qa-full's SKILL.md, did every check by hand and
marked eight ledger rows as run.

Replaying the hook over the six baseline transcripts: it would have blocked
five runs and passed the one clean run, matching the grader exactly.

The NOT READY verdict in every run is correct: `web/CheckoutForm.tsx` is new
public surface and the project has no toolchain to test it.

## Reading

- The prompt change (1 + 2) did the work: every after-run invoked every
  expected sub-skill without the hook ever blocking. The hook is a backstop,
  not observed running or blocking live (a passing hook is silent); verified by bats and by replaying it over the six baseline transcripts (5 blocked, 1 passed, matching the grader).
- Cost: invoking the skills loads their full instructions, so a qa-full run
  used about 60% more tokens (151k to 243k). That is the price of the checks
  actually running as written. The larger lever from the cost audit (running
  the heavy gstack sub-skills in subagents with short handoffs) would offset it.
- n = 3 per arm. 21/21 against 12/21 is a large gap, but it is one fixture.

## Gaps

- Hook not observed running or blocking live; evidence is bats plus the replay.
- One fixture, no browser checks exercised (no dev server).
- Two after-run agents rewrote their own commits with `git filter-branch` to
  strip attribution trailers the harness asked for; harmless in a disposable
  repo, worth knowing.
