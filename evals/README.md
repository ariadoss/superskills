# Superskills evals

Behavioural tests for the skills, run with Claude Code's `claude plugin eval`.
Each case is a prompt a user might type plus graders that check what Claude did
(which skill fired, whether it mutated anything, what the reply contains). The
rubric, sampling plan and analysis protocol are in [`RUBRIC.md`](RUBRIC.md).

**Cost:** every run and every `llm` grader vote is a real model call on your
account. The default is 3 runs per case per arm and two arms (with/without the
plugin), so 8 cases ≈ 48 agent runs plus judge calls. Use `--max-cost-usd` and
start with one case.

```bash
# one case, one run, no baseline — cheapest way to debug a case
claude plugin eval . --case doctor-direct --runs 1 --ablation none \
  --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet

# the whole suite with the no-plugin baseline (what a release should pass)
claude plugin eval . --trust-plugin --no-publish --scaffold --allow-tools Bash \
  --judge-model sonnet --max-cost-usd 30 --json evals/results/last-run.json
```

Flags, and why:

- `--scaffold`: doctor cases build a fixture install tree; the script runs as you.
- `--allow-tools Bash`: the doctor skill calls `scripts/doctor.sh`; Bash runs sandboxed.
- `--judge-model sonnet`: judge accuracy is a measured quantity; do not downgrade it.
- `--no-publish`: keep the HTML report local (the default publishes to claude.ai).
- `--trust-plugin`: you wrote this suite; non-interactive runs cannot ask.

Results land in `evals/results/<timestamp>/` (git-ignored). Reports from
analysed runs live in `evals/reports/`.

**Layout notes.** The four `doctor-*` cases share one scaffold,
`_lib/doctor-fixture.sh` (a directory with no `prompt.md` is not a case). Their
`skill-fired`, `read-only` and `no-false-ready` graders are deliberately
duplicated per case: the harness has no shared-grader mechanism, so each copy
carries a comment saying to edit all four together.


**In-session evals (free under the plan).** Some reports run the case prompts
through in-session subagents instead of `claude plugin eval` and grade the
transcripts: `reports/2026-09-24-description-trim.md`,
`reports/2026-09-24-qa-full-skill-invocation.md` and
`reports/2026-09-25-daily-qa-skill-invocation.md`. The /qa-full fixture repo is
built by `_lib/qa-full-fixture.sh <dir>` and the /daily-qa one by
`_lib/daily-qa-fixture.sh <dir>` (not cases: they have no `prompt.md`).

**Do not use in-session subagents for routing evals.** Tested directly: two
45-run arms differing only in one prompt clause fired a skill in 22% and 26% of
runs (`reports/2026-09-25-no-preamble-rerun.md`), against 12/12 for comparable
cases under `claude plugin eval`. The ~25% ceiling is the harness, not prompt
wording, and a suite that fires that rarely cannot discriminate a `description`
edit: true negatives are trivially near 1. Both arms also found **zero** false
triggers across 228 neighbour-scoped negatives, so description wording is not
where routing precision is lost. That question is closed, and reopening it costs
~3.5M tokens per arm for no signal. Six skills (`debug`, `verify`,
`test-coverage`, `db-optimize`, `web-perf`, `defense`) fired in 0 of 36 attempts
in both arms; that is a skill-design question, not a measurement one.

If you run this suite anyway, grade with `_lib/grade-routing.py` and heed its two
hard-won rules: only a transcript carrying the launcher's marker sentence is a
run (a fan-out skill's own subagents each get a transcript naming the same
fixture), and completion is a `SubagentHandback` *tool_use*, never a `grep` for
that string in raw transcript text. Fixtures: `_lib/qa-full-fixture.sh` plus
`_lib/routing-fixture-extra.sh`.
