# Pre-registration: /qa-full autonomy and the /write-plan review chain (2026-11-07)

Written before any skill edit. Free method: in-session Sonnet `general-purpose`
subagents, before and after, graded from transcripts. No `claude plugin eval`
(billed). At most two subagents at once.

## Question 1: does /qa-full run to a verdict without being pushed?

Evidence from a real session (MVC-Lite, 2026-11-07): the agent ended turns with
status updates ("next in the pipeline: ..."), the user had to say "run the full
QA pipeline" and "stop asking me", it paused to ask `/pentest` authorization
mid-run, it ran checks as background agents instead of Skill calls, and the
stop hook fired about 20 times on those waiting turns.

Changes under test (qa-full SKILL.md + ledger hook):
1. Run-to-completion rule: the only legal stops are the final verdict or a
   real blocker; a progress update is not a stop.
2. All yes/no questions (pentest authorization, dirty tree, Codex, dev URL) are
   asked once in Step 1, or pre-approved in the project's CLAUDE.md. None later.
3. Checks run in the foreground through the Skill tool, never as background
   agents the turn then waits on.

Fixture: `evals/_lib/qa-full-fixture.sh`, with its CLAUDE.md edited in a copy
to say "the owner authorizes /pentest" for the autonomy arm only. Prompt:
"Run /qa-full on this branch."

Per-run binary grades (from the JSONL transcript):
- G1 no AskUserQuestion call after the first AskUserQuestion-free tool call of
  Step 2 (i.e. none mid-pipeline)
- G2 zero Agent calls with `run_in_background: true` for a pipeline check
- G3 a report exists under `qa-full-reports/` with a verdict line
- G4 every ledger row marked RAN-CLEAN/FIXED/UNFIXED has a Skill call
  (`qfl_missing` empty)
- G5 the run never ends with the report missing or marked INCOMPLETE/NOT RUN
  for a triggered check

Adopt if, with n=3 per arm: G1, G2, G3 and G5 hold in 3/3 after-runs, G4 stays
at 3/3 (no regression from 21/21 invoked), and mean tokens rise by no more than
25% over baseline. A baseline that already passes G1-G5 3/3 means the edit is
unnecessary and is dropped. Not measurable here: the Stop-hook nag (no hook
fires inside a subagent), so the hook change is covered by bats only.

### Amendment (after baselines b1, b2; before any skill edit)

A subagent has one turn and no user, so G1 (no mid-run question) and G2 (no
background agents) pass trivially at baseline (b1, b2: 0 questions, 0 background
agents). They cannot show the turn-ending and mid-run-ask fixes work. The
after-arm is therefore scored on G3-G5 plus the number of expected checks run
through the Skill tool (baseline b1 9, b2 1; the spread is itself the defect:
the agent sometimes does checks by hand). Adopt on: expected-skill calls at
least 9 in 3/3 after-runs and G4 unbacked rows = 0. The turn-ending, mid-run
ask and hook false-positive fixes rest on bats tests and a replay of the
MVC-Lite transcript, not on this eval.

## Question 2: is /autoplan a better /write-plan handoff than /plan-eng-review?

Facts checked in the gstack 1.97.0.0 clone: `/plan-eng-review` is retired as a
slash command (GST-1698); `/autoplan` always runs a CEO phase, a design phase
only on UI scope, an eng phase always, and a DX phase only on developer-facing
scope. There is no eng-only flag (only `--ceo-only`).

Arms, on the same finished plan from existing `evals/writeplan-*` cases
(`writeplan-simple-crud`, `writeplan-test-strategy`), n=2 each (pilot, not a
rate estimate):
- A (today): follow the current write-plan text, which says invoke
  `/plan-eng-review` as a slash command.
- B: hand off to `/autoplan`.
- C: manual pointer skill that runs the eng methodology only
  (`gstack/plan-eng-review/SKILL.md`).

Per-run grades: H1 a review actually ran (skill or methodology file loaded);
H2 a Test Plan Artifact was written; H3 plan file changed only inside its
Test Plan / task sections (no product-scope rewrite); H4 AskUserQuestion count;
H5 subagent tokens.

Decision: adopt B as the default only if H1 and H2 hold in 4/4 B-runs, H3 holds
in at least as many B-runs as C-runs, and B tokens are at most 1.5x C tokens.
Otherwise the default handoff is C (eng-only) and `/autoplan` stays an opt-in
for plans that need CEO/design/DX review. A is expected to fail H1 (the slash
command does not exist); if A passes H1 4/4 the retirement does not bite here
and Question 2 is moot.

## Rules

- Baseline runs finish before any tree edit; after-runs on a clean committed
  tree so agents do not see a dirty SKILL.md in `git status`.
- Report every number, including regressions, in the final report.
