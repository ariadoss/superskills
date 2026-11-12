# Pre-registration: splitting /qa-full into a core file plus step files (2026-11-10)

Written before any run of the split. Thresholds below do not change after results come in.
Extends `2026-11-03-qa-full-context-PREREG.md` (same four adoption ideas, now covering every step after Step 3).

## Question

`/qa-full` was one 52,188-byte `SKILL.md`. After a context compaction the host re-attached only its first
~20,694 characters, which ends inside Step 3. Steps 4 to 10, the report format, the ledger and the
"never stop before the report" rule were lost, and two real runs stopped early. The split keeps the core
at about 16.6 KB (frontmatter, hard rules, a resume rule, one stub per step with the trigger text) and moves
each step's body to `steps/NN-*.md`, read only when that step runs. Does the split keep the skill as
effective, and does it fix the compaction failure?

## Arms

- **A, monolith:** the pre-split file from commit `3f8da56` plus the uncommitted Step 9c wording fix (scratchpad snapshot `mono/qa-full/SKILL.md`).
- **A-trunc, compacted monolith:** the same file cut at 20,694 characters, simulating what the host re-attaches after compaction.
- **B, split:** `skills/qa-full/SKILL.md` plus `skills/qa-full/steps/` as in the working tree.
- Each arm is copied to the scratchpad; the subagent is told the arm's folder and reads from there. For B, the agent is told the folder is the skill's base directory.
- Subagent: in-session Sonnet `general-purpose`, at most five at a time. Free under the plan. `claude plugin eval` is not used.

## Fixtures

- **heavy:** `evals/_lib/qa-full-fixture.sh` (planted failing test, secret, SQL injection, N+1, inaccessible form, root Dockerfile).
- **light:** `evals/_lib/qa-full-light-fixture.sh` (docs-only branch; almost nothing triggers).

A run follows its arm's text end to end up to the final report, with the user's Step 1 answers pre-given
(commit the tree, no Codex, no `/code-review ultra`, no pentest authorization). Sub-skills are invoked with the Skill tool.

n = 3 per arm per fixture for A and B (12 runs). A-trunc runs on heavy only, n = 3. Total 15.

## Measures (graders already in the repo)

- `evals/_lib/qa-full-grade.sh`: invoked skills, unbacked ledger rows, secret absent, tests green, report path.
- `evals/_lib/transcript-context.py`: bytes loaded, by tool and skill. Step-file reads are found by path (`/steps/`).
- A run **reaches the end** when a report file exists whose ledger has no open row (no NOT RUN, INCOMPLETE, pending or blank result).
- A heavy run is **correct** when it reaches the end, `unbacked=0`, `secret_absent=1`, and it invoked every one of: `review`, `clean-code`, `defense`, `db-optimize`, `qa`, `design-review`, `test-coverage`.
- A light run is **correct** when it reaches the end, `unbacked=0`, and it invoked none of `db-optimize`, `qa`, `design-review`, `web-perf`.

## Gates (all must hold to adopt the split)

1. **Core size:** `skills/qa-full/SKILL.md` is at most 18,000 bytes. (Measured before any run: 16,611.)
2. **Lossless:** every non-blank line of the monolith appears verbatim in the core or a step file, except the
   16 lines rewritten to point at the single trigger helper or the moved config file (listed in the commit message
   and enforced by a bats test that checks the step files exist and the core names each).
3. **No loss of effect:** per fixture, B correct runs is at least A correct runs minus 1. Across both fixtures, B total correct is at least A total correct.
4. **Untriggered steps stay unread:** in light B runs, at least 2 of 3 never Read any of `steps/05`, `06`, `07`, `08`. Median total bytes loaded by B light is at least 6,000 lower than A light.
5. **Triggered steps are read first:** in heavy B runs, for each of Steps 3, 4, 5, 7, 9 the step file is Read before that step's first Skill call, in at least 90% of such pairs.
6. **Compaction fix:** B heavy reaches the end in at least 2 of 3 runs. A-trunc heavy is reported as observed; it is the baseline that shows whether the old failure reproduces. If A-trunc also reaches the end in 3 of 3, the compaction claim is not reproduced in this harness and the result says so (the split can still be adopted on gates 1 to 5, as a size saving).

If gate 3 fails, fix wording before structure (stub text, resume rule) and re-run once; do not loosen the threshold.

## Limits

n = 3 per cell is a pilot, not proof. An in-session agent does not see a real compaction; A-trunc approximates it
by truncating the text it is given. Fixtures are small and synthetic. Step-file read order is measured from tool order.
The other three splits (`daily-qa`, `subagent-driven-development`, `pentest`) are not covered by this run; they get byte
measurement, the existing behaviour tests, and one smoke run each, and are applied only if gates 1 to 3 pass here.
