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

- `--scaffold` — doctor cases build a fixture install tree; the script runs as you.
- `--allow-tools Bash` — the doctor skill calls `scripts/doctor.sh`; Bash runs sandboxed.
- `--judge-model sonnet` — judge accuracy is a measured quantity; do not downgrade it.
- `--no-publish` — keep the HTML report local (the default publishes to claude.ai).
- `--trust-plugin` — you wrote this suite; non-interactive runs cannot ask.

Results land in `evals/results/<timestamp>/` (git-ignored). Reports from
analysed runs live in `evals/reports/`.

**Layout notes.** The four `doctor-*` cases share one scaffold,
`_lib/doctor-fixture.sh` (a directory with no `prompt.md` is not a case). Their
`skill-fired`, `read-only` and `no-false-ready` graders are deliberately
duplicated per case: the harness has no shared-grader mechanism, so each copy
carries a comment saying to edit all four together.

