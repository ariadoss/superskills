# Results: splitting /qa-full into a core file plus step files (2026-11-10)

Method and gates are in `2026-11-10-qa-full-split-PREREG.md`, written before any run. In-session Sonnet
subagents, free under the plan. n = 3 per cell: a pilot, not proof.

## Gate by gate

| Gate | Result |
|---|---|
| 1. Core at most 18,000 bytes | **Pass.** 16,611 bytes (16,796 after the round-two wording sentence). The monolith was 52,188. |
| 2. Lossless | **Pass.** Every line moved verbatim except 16 reworded to point at the shared trigger helper; `tests/qa-full-split.bats` pins the files. |
| 3. No loss of effect | **Pass, with noise.** Heavy correct runs: monolith 1 of 3, split 2 of 3. Light: 3 of 3 each. Totals 5 and 4. |
| 4. Untriggered steps stay unread; fewer bytes | **Pass.** 3 of 3 light split runs never read steps 05 to 08. Median bytes loaded 196,707 (split) against 275,532 (monolith). The spread between runs is far larger than the 52 KB file difference, so read the byte number as direction, not size. |
| 5. Step file read before its sub-skill, at least 90% | **Fail, twice.** Round one 9 of 15 pairs (60%). After a sentence in the core saying to read the file first, round two 6 of 15 (40%); one run read no step file at all. |
| 6. Compaction fix | **Pass.** All 3 truncated-monolith runs stopped inside Step 3 and left every later check INCOMPLETE (only `review` and `clean-code` ran). All 6 split heavy runs invoked the later checks and wrote a report. |

## What it means

The compaction failure reproduces and the split fixes it. That was the reason for the work.

The split did not make agents read the step files reliably. They ran the sub-skills from the stub text
(which keeps trigger wording and skill names) and often skipped the file that holds commit format and
ledger evidence rules. Outcomes stayed close to the monolith, but the unread files are where the bookkeeping
lives. Per the pre-registration, a failed gate 5 after one wording fix is not adopted by loosening the bar.

Caveats: every heavy run ended NOT READY because `/qa` and `/web-perf` had no running app (the fixture has no
dev URL), so "reaches the end" here means "wrote a report", not "closed every ledger row". Grading counted
sub-skill calls and report files; open-row keyword counts were too noisy to use. Round two also changed the
core text, so rounds are not a clean A/B.

## Options

1. Do not adopt the split for `/qa-full`; keep the monolith and fix compaction another way (a resume rule
   plus a Stop hook that blocks while any ledger row is open).
2. Adopt a hybrid: keep each step's invocation, ledger and commit rules in the core, and move only the long
   background text (tool recipes, examples) out. Needs its own pre-registration and run.
3. Adopt the split anyway as a size saving and accept the skipped-read risk. 
