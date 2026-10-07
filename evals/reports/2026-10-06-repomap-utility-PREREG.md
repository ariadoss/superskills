# PREREG — repomap utility (does the map help the agent?)

Registered before any run of `repomap-nav-task`. Question: does running
/repomap first (arm B), or merely having REPOMAP.md present (arm C),
improve task correctness or exploration cost over cold start (arm A)?

## Pilot framing

This is a **pilot**, not a confirmatory experiment: n=3/arm means one run
is 0.333 of any pass-rate. Fixed in advance:

- |Δ| < 0.34 between arms = **"no signal at this scale"** — no adoption,
  no wording stronger than "unremarkable at n=3".
- Δ ≥ +0.34 (a full run's worth) in the primary endpoint = signal
  licensing an **optional n=5 confirmatory** follow-up, not adoption.
- skill-fired ≥ 2/3 in arm B is a gate: below that, arm B is
  under-powered → no verdict, reported as such.

## Arms

A cold · B skill-first (one extra prompt line — the intervention:
`Start by running /repomap to orient yourself (write REPOMAP.md), then do
the task below.` plus the vendored-toolchain pointer
`REPOMAP_HOME=$PWD/fixture-repo/vendor`) · C map pre-injected (same map
file for every C run, generated once from the fixture by the executor and
committed at `evals/repomap-nav-task/REPOMAP.md`; prompt identical to A).

Between arms NOTHING is committed: the prompt edit and the fixture.sh
artifact-copy line are uncommitted tree state, restored to the A-form
before the final commit.

## Run-order and pilot gate

Order (fixed): **pilot → A → B → C**. The pilot is 1 run of the arm-B
prompt at `--max-cost-usd 2`, verifying from the trace that the vendored
toolchain actually executed inside `./fixture-repo` and wrote REPOMAP.md
there ($HOME is unreadable inside sandboxed eval runs — the vendored copy
is the agent's only path to the tool). If the pilot fails on
toolchain-in-sandbox (deps/network), that is the **headline finding** and
only arms A and C run, with all verdict claims narrowed accordingly.

## Fairness

Graders grade claimed file changes vs the fixture's ground truth, never
vocabulary; the map artifact is committed in the case dir so C runs are
byte-identical; single-plugin check mandatory before reading numbers.

Single-plugin protocol (round-2 contamination lesson,
`2026-10-06-writeplan-testphilosophy.md`): running `claude plugin eval .`
from THIS worktree registers two superskills plugins (the worktree target
plus the canonical main checkout — verified in the `suite.plugins` arrays
of `2026-10-06T18-31-14-447Z`/`...18-56-22-576Z`), which the check
`len(plugins)==1 and 'worktrees' not in plugins[0].path` must reject.
Therefore every run (pilot and arms) executes from a **git-less rsync
copy of this worktree at `/tmp/superskills-eval-copy`**, refreshed from
the worktree immediately before each arm so the uncommitted arm state is
what runs; the copy has no ancestor `.claude-plugin` and no git worktree
list, so exactly one plugin root can resolve. The check then reads
exactly one plugin whose path is the copy — any second entry, or any
entry containing `worktrees` or the main-checkout path, is contamination
and stops the experiment.

## Endpoints

- Primary: mean(task-correct, no-wrong-edits) per arm; task-correct is
  cross-checked against the `edits-made` tool_used edit-proof grader
  (claims without Edit-tool proofs do not count as correct at analysis
  time even if an LLM grader passed them).
- Secondary (reported only): mean turns + durationSeconds per arm,
  excluding truncated runs (partial/error/turns==max_turns reported
  separately, never averaged in); exploration-action counts (Read/Grep/
  Glob) from the archived traces (`scripts/eval-traces.sh` after every
  command); an out-of-fixture read probe per arm (whether a run read
  files outside ./fixture-repo beyond the workspace scaffold).
- skill-fired ≥ 2/3 in arm B else under-powered → no verdict.
- Budget: $12 cumulative for the whole experiment; every command capped
  `--max-cost-usd 4` (the pilot at 2); cumulative costUsd summed from the
  result JSONs before each command — stop and analyze what exists if the
  budget is crossed; abort if any single run exceeds $1.50.

## Verdict table (fixed in advance)

B>A ∧ C≈B → "run it first" justified · C>A ∧ B≈A → prefer pre-generated
maps over on-demand runs · B≡A≡C → null at this scale.

All comparisons use the pilot signal rule above: "A" means Δ ≥ +0.34 on
the primary endpoint; "≈"/"≡" mean |Δ| < 0.34. At n=3 the only honest
outcomes are "signal licensing an optional n=5 confirmatory" or "no
signal at this scale".

## Mechanics deviations from the task brief (registered before any run)

1. **Vendored dir named `vendor`, not `toolchain`.** The brief's arm-B
   line says `REPOMAP_HOME=$PWD/fixture-repo/toolchain`; the vendored
   copy instead lives at `./fixture-repo/vendor`. Reason: `vendor` is in
   the repomap tool's own EXCLUDED_DIRS, so the copy cannot pollute arm
   B's generated map — with a literal `toolchain/` dir inside the repo,
   arm B's on-demand map would list the toolchain's own ~30 source files
   while arm C's pre-generated artifact (built from a clean fixture)
   would not, an asymmetry the experiment itself would create. The
   point of the sentence — a toolchain path the sandboxed agent can
   reach — is preserved.
2. **`tests/nav-fixture.bats` grep fixed.** The brief's bats test grepped
   `notification_service.send` in `digest_job.py`, but the brief's own
   verbatim fixture imports `send_digest` directly (and the task-correct
   grader text says the job "calls send_digest"). Grep changed to
   `send_digest`; the fixture itself is byte-for-byte the brief's.
3. **fixture.sh toolchain copy is guarded** (`[ -d ~/claude-repomap-command ]`)
   so maintainers without the toolchain can still run arms A/C; only
   arm B needs it.
4. **Brief PREREG arithmetic superseded**: the brief's PREREG draft said
   "adopt if ≥ +0.10 / cap $8" and named no pilot; per the plan-eng-review
   round (commit 9bc447c) the registered thresholds are the pilot rule
   (±0.34) and $4 command caps, as written above.
