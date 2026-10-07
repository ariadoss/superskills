# PREREG — dbmap utility (does the schema map help the agent?)

Registered before any run of `dbmap-schema-task`. Question: does running
/dbmap first (arm B), or merely having DBMAP.md present (arm C), improve
diagnosing/fixing the deliberately un-indexed `orders.user_id` FK over
cold start (arm A)?

## Pilot framing

This is a **pilot**, not a confirmatory experiment: n=3/arm means one run
is 0.333 of any pass-rate. Fixed in advance (identical rule to the
repomap PREREG, `2026-10-06-repomap-utility-PREREG.md`):

- |Δ| < 0.34 between arms = **"no signal at this scale"** — no adoption,
  no wording stronger than "unremarkable at n=3".
- Δ ≥ +0.34 (a full run's worth) in the primary endpoint = signal
  licensing an **optional n=5 confirmatory** follow-up, not adoption.
- skill-fired ≥ 2/3 in arm B is a gate: below that, arm B is
  under-powered → no verdict, reported as such.

## Arms

A cold · B skill-first (one extra paragraph — the intervention:
`Start by running /dbmap against the connection in .env (write DBMAP.md),
then do the task below.` plus the vendored-toolchain pointer
`REPOMAP_HOME=$PWD/fixture-repo/vendor — the $HOME lookup paths are
unreachable in this sandbox`; the A-form prompt's connection steering —
".env — that's the only connection; use it" — stays in every arm) ·
C map pre-injected (the FULL artifact — tbls doc + the agent-authored
`## Index Analysis` section, in the skill's own output format — generated
once by the executor from a clean scratch fixture build, host-side, by
actually running the toolchain (`run.sh dbmap --dsn … -o DBMAP.md`,
byte-identical across fixture rebuilds) and authoring the Index Analysis
per the skill's five checks; committed at
`evals/dbmap-schema-task/DBMAP.md` and copied into `./fixture-repo/` by
the scaffold for arm C only; prompt identical to A).

Between arms NOTHING is committed: the prompt edit and the fixture.sh
artifact-copy line are uncommitted tree state, restored to the A-form
before the final commit. B and C receive the same information surface
(plan-eng-review finding 5): the scaffold — including the vendored
toolchain — is identical across arms; only the prompt line (B) and the
pre-injected artifact (C) differ.

## Run-order and pilot gate

Order (fixed): **pilot → A → B → C**. The pilot is 1 run of the arm-B
prompt at `--max-cost-usd 2`, verifying from the trace that: the skill
fired, the vendored toolchain executed inside `./fixture-repo`, DBMAP.md
was written there, the agent appended its `## Index Analysis`, and no
stall occurred on the skill's interactive "which connection?" question —
the prompt names .env as the only connection precisely so that ask is
never reached. If a run stalls or fails on that question anyway, the
stall is recorded verbatim as a **headless-usability finding** (a fact
about the skill's headless ergonomics, separate from map efficacy), per
the plan. If the pilot fails on toolchain-in-sandbox (python/tbls not
reachable, deps/network), that is the **headline finding** and only arms
A and C run, with all verdict claims narrowed accordingly.

## Fairness

Graders grade the reply's diagnosis/SQL/changed-files list against the
fixture's ground truth, never vocabulary; the artifact is committed in
the case dir so C runs are byte-identical; single-plugin check mandatory
before reading numbers. task-correct is an `llm` grader; the mechanical
side-evidence is the `schema-inspected` tool_used indicator (a sqlite
CLI/python probe or tbls run, i.e. the agent actually inspected the
schema rather than guessing from the prompt's framing). Deliberately NO
Edit-tool proof grader: the Task-1 runs showed this model edits via
Write/Bash heredocs, never Edit, and this task expects at most query-file
edits — an Edit-proof grader would read 0 across the board and drag
every arm equally (registered lesson, `2026-10-06-repomap-utility.md`).

## Protocol facts carried from the repomap experiment (registered there, re-registered here)

1. **Runs execute from a git-less /tmp rsync copy** of this worktree
   (`/tmp/superskills-eval-copy`), refreshed from the worktree
   immediately before each arm so the uncommitted arm state is what runs:
   a worktree cwd double-registers plugins in `suite.plugins` (worktree +
   canonical main checkout), making the single-plugin assertion
   unsatisfiable otherwise. Verify the copy's path has no `.git` and
   every run's `suite.plugins` shows exactly
   `[('superskills', '/private/tmp/superskills-eval-copy')]` before
   reading numbers.
2. **Every eval command grants `--allow-tools 'Bash Edit Write'`** —
   `Bash` alone withholds Edit/Write and the harness warns; the case's
   `allowed_tools` always declared them.
3. **The scaffold's `$HOME` is sealed**, so the B-arm toolchain is
   vendored into the fixture from an ABSOLUTE source path
   (`cp -R /Users/danilosapad/claude-repomap-command …`, with the
   `$HOME` lookup kept first for other maintainers), and the B prompt
   names `REPOMAP_HOME=$PWD/fixture-repo/vendor` with the in-workspace
   absolute path.
4. Every command: `--max-cost-usd 4 --keep-temp` (pilot 2), then
   `scripts/eval-traces.sh` from the run dir; cumulative experiment
   budget **$12** (sum `costUsd` from the result JSONs before each
   command — stop and analyze what exists if crossed); abort if any
   single run exceeds $1.50.
5. The toolchain's `run.sh` is patched import-aware and was verified
   host-side for BOTH `repomap` and `dbmap --list`, and now end to end
   for dbmap generation (tbls 1.94.4 via PATH) against this fixture.

## Endpoints

- Primary: mean(task-correct, no-wrong-edits) per arm — computed from the
  individual grader passes (the harness `score` averages all four
  graders including the two indicators; the primary ignores that
  aggregate and uses the two llm graders only).
- Secondary (reported only): mean turns + durationSeconds per arm,
  excluding truncated runs (partial/error/turns==max_turns reported
  separately, never averaged in); exploration-action counts (Read/Grep/
  Glob tool calls, expected ~0 with exploration Bash-carried as in the
  repomap runs) plus Bash call counts from the archived traces
  (`scripts/eval-traces.sh` after every command); an out-of-fixture read
  probe per arm (reads outside ./fixture-repo beyond the workspace
  scaffold; the vendored toolchain is inside it).
- Indicators (reported, never in the primary): skill-fired (arm-B gate ≥
  2/3, else under-powered → no verdict); schema-inspected.
- Headless-usability observations (stalls on the skill's connection
  question) recorded verbatim, reported separately from map efficacy.

## Verdict table (fixed in advance)

B>A ∧ C≈B → "run it first" justified · C>A ∧ B≈A → prefer pre-generated
maps over on-demand runs · B≡A≡C → null at this scale.

All comparisons use the pilot signal rule above: "A" means Δ ≥ +0.34 on
the primary endpoint; "≈"/"≡" mean |Δ| < 0.34. At n=3 the only honest
outcomes are "signal licensing an optional n=5 confirmatory" or "no
signal at this scale".

## Mechanics deviations from the task brief (registered before any run)

1. **The vendored toolchain copy prunes `tests/`.** The toolchain's own
   detector tests contain SQLAlchemy DSN strings; vendored whole, they
   surface as a phantom second connection in arm B's `dbmap --list`
   (verified on the scratch build: "Found 2 database connection(s)",
   the second a fake `postgresql://u:****@h:5432/db` from
   `tests/test_detector.py`). The prompt's single-connection steering
   would then contradict the tool's own output. `run.sh` never executes
   `tests/`; after pruning, `--list` reports exactly the one .env
   connection and generation still works (re-verified).
2. **No Edit-tool proof grader**; `schema-inspected` (Bash tool_used on
   `pragma_index_list|sqlite3|tbls`, min 1, command-anchored) replaces
   it as the mechanical indicator — the Task-1 grader corrections.
3. **Carried harness facts** (sealed `$HOME` → absolute toolchain path;
   `--allow-tools 'Bash Edit Write'`; git-less /tmp run copy) are
   protocol, not deviations, per the repomap PREREG — restated under
   "Protocol facts" above.
4. **The arm-C artifact's Index Analysis was authored by the executor**
   following the skill's own five-check recipe and output format (the
   skill defines that section as agent-authored, appended after the
   toolchain run) — this is the registered construction of "actually
   running /dbmap once against a scratch fixture build host-side".
5. **One bats assertion line carries the repo's errexit guard**: the
   brief's verbatim `[ -f …app.db ] && [ -f ….env ]` is a bare `&&`
   chain, which the repo's own `tests/bats-assertions.bats` rejects
   (bash-3.2 hazard); a `|| false` terminator was appended — the same
   guard the brief itself applies to its `idx` line. No other byte of
   the brief's fixture/test changed.
