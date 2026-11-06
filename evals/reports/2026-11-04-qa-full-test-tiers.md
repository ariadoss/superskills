# qa-full fast/slow test tiers: results (2026-11-04)

Pre-registration: `2026-11-04-qa-full-test-tiers-PREREG.md` (written before any run).
Method: in-session Sonnet subagents, before arm (`HEAD` SKILL.md) vs after arm
(working-tree SKILL.md), 3 runs per scenario per arm, Step 2 and Step 10 item 1 only.

## Result

| Scenario | Before | After |
|---|---|---|
| fixbug (real bug in the fast tier) | 0 of 3 | 3 of 3 |
| flaky (fails on first run only) | 0 of 3 | 3 of 3 |
| Pooled | 0 of 6 | 6 of 6 |

Decision rule (after >= 5 of 6 and before <= 3 of 6): met.

What the before arm did: all three fixbug runs started with `npm test`, which runs both
tiers at once. All three flaky runs treated the flake as a bug, edited the test and
committed. One of them (before-flaky-3) did rerun the test alone first, then committed a
change anyway.

What the after arm did: fast tier first in every run, a single-test rerun and a FLAKY
note for every flake, no commit for a flake, both tiers on the final HEAD.

## Deviation from the pre-registration (disclosed)

The grader grouped log entries into one test run when they were less than 1,500 ms apart.
after-flaky-3 reran the flaky test alone, then ran the whole fast tier 174 ms later, so the
two runs merged and the solo rerun was missed (a false negative). The gap is now 100 ms
(files in one run start within a few ms; back-to-back runs were at least 150 ms apart) and
a bats test pins the case. All 12 runs were re-graded. No before-arm result changed
(before-flaky-3 now shows a solo rerun but still fails: it committed). Under the old gap
the pooled score was 0 of 6 vs 5 of 6, which also meets the rule.

## Limits and findings

- **Grader gap.** Rule 1 checks only the first test run. after-fixbug-2 and
  after-fixbug-3 both report running the whole suite on a still-red tree later, by
  accident (a chained command fell through to `npm test`). Both pass the grader as
  written. So the after arm is not perfectly fail-fast; it starts fast-tier-first but can
  slip. Candidate follow-up: say plainly in Step 2 never to run the full suite while the
  fast tier is red, and grade "no slow entry before the fast tier first goes green".
- **Instruction-following.** The after arm reran the flake alone because the new text says
  to. That shows the text is followed, not that the behavior is independently better.
- **Scope.** Truncated pipeline (Step 2 and Step 10.1), tiny fixture, Sonnet only, n = 3.
- Cost: 12 subagent runs of about 57-62k tokens each, under the plan allowance; no
  `claude plugin eval` run.

## Re-run with the Step 2 "never run the full suite on red" sentence (after2)

Pre-registered in the addendum to the PREREG file: adopt the sentence if all three fixbug
runs pass all four rules, including rule 4 (no slow-tier file starts before the failing
unit test first passes).

Result: **0 of 3 pass.** The pre-registered bar (3 of 3) is not met, so the sentence is
not shown to change behavior.

| run | first run fast-only | no slow tier on red (rule 4) | both tiers on final HEAD | fixed the cause | what the log shows |
|---|---|---|---|---|---|
| after2-fixbug-1 | no | no | yes | yes | opened with `npm test` (full suite) on the red tree; self-reported |
| after2-fixbug-2 | yes | no | yes | yes | a chained command ran the slow tier while red after a failed edit; self-reported |
| after2-fixbug-3 | yes | no | yes | yes | slow tier started in a run where the unit test still exited 1; **the report said it did not** |

Findings:

- All three runs fixed the real cause and finished with both tiers green on the final
  HEAD. The two-tier structure works; the extra sentence does not stop the full-suite
  slip. Two agents slipped through a chained command (`unit; npm test`), which is exactly
  what the sentence names.
- One report was wrong about its own run. Only the timestamped log caught it, so a
  self-report is not evidence for this rule. This also means the earlier statement that
  the first-round after-fixbug-1 run had no slip rested on its report alone. Those
  runs have no exit records, so rule 4 cannot be applied to them after the fact.
- n = 3 per arm, one scenario, one model. This is a directional check, not a proof.
