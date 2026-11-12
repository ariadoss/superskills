# Results: injecting /qa-full step files with a PreToolUse hook (2026-11-11)

Method and gates: `2026-11-11-qa-full-step-hook-PREREG.md`, written before any run. In-session Sonnet subagents,
free under the plan. n = 3 per cell: a pilot, not proof.

## Gate by gate

| Gate | Result |
|---|---|
| 1. Delivery, at least 90% of triggered pairs | **Pass, 18 of 18 heavy pairs (100%).** Every step file (3, 4, 5, 6, 7, 8, 9) arrived before its sub-skill ran. Earlier read-first rates were 60% and 40%. Light runs: 12 of 12 as well. |
| 2. No loss of effect | **Pass.** Heavy correct 2 of 3 (runs 1 and 3 invoked all seven required checks, nothing unbacked; run 2 never reached design-review or test-coverage and left one row unbacked). Light correct 3 of 3. Baselines: monolith 1 of 3, split 2 of 3. |
| 3. No over-injection | **Pass.** Light runs received only the files for steps 3, 4, 9 and 9b, never 5 to 8. |
| 4. No double work | **Unit-tested only** (`tests/qa-full-step-hook.bats`: once per agent, skipped when already read). Not checked in the transcripts. |

## What happened along the way

The first batch of runs was thrown away. The arm folder was named `arms/C`, and the hook only activates for a
folder named `qa-full`, so it never fired (0 of 8 pairs). I stopped those runs and reran everything on
`arms/Ch/qa-full`. That is the only change to the PREREG setup. It also shows the activation rule is strict: a
skill copied to a differently named folder gets no injection and falls back to the core text.

Two light runs ended NOT READY or with an inline adversarial read only, because five agents were already running
and `/review` could not start its own subagent ("Concurrent subagent limit"). That is a harness limit of this
eval, not a skill result.

## What it means

The hook fixes the problem that sank the split: the harness hands over the step file, so reading it no longer
depends on the model. Effect held at the split's level. The hook only helps tools that run Claude Code hooks, so
Codex and Cursor still lean on the core text.

Limits: n = 3, synthetic fixtures, no real compaction, heavy runs all ended NOT READY (no running app for `/qa`
and `/web-perf`), so "correct" means required checks invoked and ledger backed.
