# /superskills loader eval (2026-11-21)

Change under test: the new `/superskills` skill and `scripts/superskills-load.sh`, which load a skill pack index (`design`, `marketing`) or a single skill into context on demand.

## Method

In-session Sonnet subagents, three runs per case, graded deterministically from the transcripts (tool calls parsed by a script, no LLM judge, so no judge calibration). The method is free: no `claude plugin eval` run was made. The positive class for reporting is FAIL. Gates and the per-run rule were written before the first run (the one amendment is below).

| Case | Prompt | Expected |
|---|---|---|
| P1 | `/superskills design` | pack index |
| P2 | "load the marketing skills into context" | pack index |
| P3 | `/superskills typography` | one skill's full text |
| P4 | "use the seo-audit skill on my homepage" | the skill, found through the loader |
| N1 | "is my superskills install healthy?" | `/superskills-doctor`, not `/superskills` |
| N2 | "give me a layout for a pricing page" | `/superskills` must not fire |

Gates: P1 to P4 each at least 2 of 3 runs pass, and pooled at least 10 of 12. N1 and N2 pooled at least 5 of 6. Any mutation command (`./setup`, git pull, install) fails the gate outright.

## Failure classes found by the first run, and the fix

The first run of P1 and P2 passed the original rule 6 of 6, but reading the transcripts showed two problems the rule had missed. The rule was amended before the second run, and the gates did not change.

- **Index too big.** The marketing index was 66KB, the harness truncated it, and agents burned extra tool calls reading a saved file. Fix: the pack index now has one line per skill (name plus a description capped at 80 characters) and no path column. It is 17KB, and a test holds it under 25000 characters.
- **Miscounts.** Agents counted the 37 design skills by hand and reported 36, 35 and 35. Fix: the loader prints a `PACK <pack>: N skills.` header, and the reply quotes it.

## Results after the fix

| Case | Pass | Notes |
|---|---|---|
| P1 | 3/3 | count 37, no truncation, 2 tool calls each |
| P2 | 3/3 | count 174, no truncation, 2 tool calls each |
| P3 | 3/3 | full text of `design-skills/typography` loaded, nothing applied |
| P4 | 2/3 | run 3 failed (below) |
| N1 | 3/3 | all three invoked `/superskills-doctor`, none invoked `/superskills` |
| N2 | 3/3 | no skill invoked at all |

Pooled P1 to P4: 11 of 12. Pooled N1 and N2: 6 of 6. No mutation command ran. Every gate passes.

One P4 run is the failure: it located `seo-audit/SKILL.md` with `find` and read it directly, so `/superskills` never fired. The skill's content was still used, but the rule asks for the loader, so it counts as FAIL. If this repeats, the fix goes in the `description` wording first.

In all three P4 runs the agent then stopped to ask for the homepage URL. That is a reasonable reply to a prompt with no URL, and it was not graded.

## Limits

- P3, P4, N1 and N2 have no before-run, because the fix did not touch the description. Only P1 and P2 have a baseline.
- The near-miss against `/superskills-upgrade` was not run, because an upgrade must never run live.
- N2 had no "text only" instruction; the agents answered in prose, so a file-writing reply could not have masked a trigger.
- n is 3 per case. Read the counts, not the percentages.
- The new skill was linked into `~/.claude/skills` by hand for the run. `./setup` has not been run, so ZCode still does not see it.
