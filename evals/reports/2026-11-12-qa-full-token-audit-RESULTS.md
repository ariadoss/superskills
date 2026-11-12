# Results: token audit of the existing qa-full eval transcripts (2026-11-12)

Post-hoc analysis of transcripts that already existed — no new runs, no credits.
Not pre-registered: it is descriptive, with recommendations, not an adoption gate.
Source: the 2026-11-10 split eval (arms A monolith, B and B2 split, T truncated
monolith), the discarded 2026-11-11 arm C, and the 2026-11-11 step-hook eval (arm
Ch), all run as in-session Sonnet subagents.

## Method

Each `agent-*.jsonl` transcript was classified by its first user message into a
qa-full run, a child agent of a run, or unrelated. Per assistant message,
`input_tokens + cache_creation + cache_read` were summed ("run tokens" — the
total token flow the model processed; cache reads dominate, which is the right
relative measure even though they bill less). Context bytes were attributed by
matching each tool result and each hook/attachment payload back to the call that
produced it. Bytes are a proxy (~4 chars per token). n = 3 per cell; medians.

## Token totals by arm (medians)

| Arm | Heavy: run tokens | Heavy: output | Light: run tokens | Light: output |
|---|---|---|---|---|
| A monolith | 14.36M | 63,785 | 5.76M | 23,156 |
| B split (round 1) | 8.46M | 37,990 | 3.90M | 14,979 |
| B2 split (round 2) | 11.54M | 44,815 | — | — |
| Ch split + hook | 10.26M | 38,314 | 4.59M | 17,587 |

Arms C (hook never activated; runs stopped early) and T (truncated by design)
are excluded. Against the monolith, split + hook processes **29% fewer tokens on
heavy runs** (10.26M vs 14.36M) and **20% fewer on light runs** (4.59M vs 5.76M);
output drops 40% heavy, 24% light. The earlier report's byte proxy (196,707 vs
275,532 median bytes loaded) understated the gap. Ch sits below B2 (same core
text, plus delivery) while fixing the split's delivery failure.

## Where a run's context actually goes (Ch runs, ~129KB tool-result + attachment bytes per run)

| Contributor | Per run | Share |
|---|---|---|
| `/review` section files (adversarial, review-army, checklist, plan-completion) | ~29.6KB | 23% |
| Command output (cat/ls/sed/git status/git diff/wc) | ~40KB | 31% |
| qa-full core SKILL.md | 17.8KB | 14% |
| Hook-injected step files (triggered steps only) | ~10KB heavy, less light | 5–8% |
| Other reads and skill bodies | rest | ~25% |

In monolith-arm runs the same `/review` files cost ~63KB per run and the qa-full
text 52KB; both dropped after the split. **qa-full's own prompt is no longer the
biggest line item — `/review`'s documentation is.**

## Double delivery found (gate 4 gap)

`qfs_step_read` matches only the literal string `steps/NN-*.md`. In Ch-heavy-1
the agent bulk-read seven step files as `cd …/steps && cat 05-database.md
06-frontend-perf.md …`; the matcher saw no `steps/NN` substring, so the hook
injected those files again when their sub-skills fired. Five of six Ch runs show
at least one step both cat-read and injected (~15KB duplicated per affected
run). Gate 4 of the step-hook eval was unit-tested only; the tests never covered
the bulk-cat form, so the eval could not catch what the transcripts now show.
Fixed the same day: the matcher also counts a `cat` whose arguments include the
step basename, plus a path boundary so `steps/05-database.md.new` no longer
counts as a read of `05-database.md`. Two bats tests cover the bulk-cat form and
the heredoc write, and the fix was checked against the Ch-heavy-1 transcript:
all six double-delivered steps now count as read, so the hook would skip them.

## Recommendations

1. ~~Fix the `qfs_step_read` matcher~~ — done with the audit (see above).
2. Treat `/review`'s section set (~30KB read per qa-full run) as the next
   prompt-efficiency target; it now costs about twice qa-full's core. That skill
   lives outside this repo, so it is a separate effort.
3. Keep the per-run token sums (not byte proxies) as the efficiency metric for
   future arms; the auditor is `evals/_lib/qa-full-token-audit.py`.
4. Bulk pre-reading of all step files mid-run (Ch-heavy-1) loads ~41KB the design
   meant to defer. Worth one sentence in the core ("read a step file when you
   reach the step, not ahead"), verified by a run before adopting.

## Limits

n = 3 per cell, synthetic fixtures, no compaction during these runs (final
contexts 94K–165K, under the window), and run-to-run spread is wide — the arm
medians are directional. "Run tokens" include cache reads, so they measure
processing volume, not billed cost.
