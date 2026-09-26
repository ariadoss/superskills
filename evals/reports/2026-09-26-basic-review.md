# Result: /basic-review and gstack's checklist on seeded review fixtures

Run 2026-09-26 against the pre-registration in
`2026-09-26-basic-review-PREREG.md` (commit 3f259f8). 42 in-session Sonnet
subagents: three arms × seven fixtures × two runs. Fixtures, answer key,
extractor and grader lived in the session scratchpad; the fixture generator is
reproducible from the PREREG table.

## Headline

| Arm | Planted bugs found | Rated as blocker | False blockers | Clean fixtures passed | Tool calls/run | Tokens/run (approx.) |
|---|---|---|---|---|---|---|
| A, no skill | 18/18 | 16/18 | 0 | 4/4 | 7.4 | ~50k |
| B, /basic-review | 18/18 | 17/18 | 0 | 4/4 | 8.0 | ~52k |
| C, B + checklist | 18/18 | 17/18 | 0 | 4/4 | 9.2 | ~58k |

F7, the bug only reachable outside the diff (a new enum value an existing
`invoice_label` does not handle), was found in 2/2 runs by every arm.

## Decisions (applying the pre-registered rules)

1. **basic-review helps or hurts: no measurable difference.** Every arm found
   every planted bug, so recall hit the ceiling and neither threshold (±2
   instances) was reached. This fixture set cannot tell the arms apart on recall.
2. **Adopt the checklist (C): yes, by the rule.** C found as many planted bugs
   as B (18 vs 18) and raised no more false blockers (0 vs 0). The rule was
   written so that a tie adopts C; the result is a tie, not evidence that the
   checklist adds recall.
3. **F7:** no difference; all arms traced the enum through its consumer.

## What did differ

- **Severity calibration.** A's free-form reports under-rated two planted bugs
  (F1's swallowed exception listed as "non-blocking"; F4's silent timeout change
  as "secondary, not necessarily blocking"). B and C each under-rated one
  (a MEDIUM on F1's swallowed exception or F3's O(N²) dedup). One run each is
  within noise at n=2.
- **Machine-readable output.** B and C always produced `[SEVERITY]
  (confidence) file:line` entries that `/qa-full` can put in its ledger and act on;
  A's reports varied in shape (prose verdicts, "Blocking"/"Non-blocking"
  headings). This is the practical reason to keep the skill as the fallback.
- **Cost.** C used about 12% more tokens and 1.2 more tool calls per run than B.

## Open coding of findings beyond the planted bugs

- Real extra issues, all MEDIUM or LOW: unhandled rejection in an async Express
  handler (F2), connection errors not retried (F3, pre-existing), first-wins
  dedup and `rec["id"]` KeyError risk (F3), a misleading refund error message
  (F7), `page_count` lacking `paginate`'s guard (F1).
- Consumer spotted beyond the key: several runs also flagged `web/static/profile.js`
  reading the renamed `userId`. That is part of the planted F4 rename, not a
  false finding.
- Nits kept non-blocking by every arm: missing tests where the repo has none,
  an unused new function (F5), bare-`pytest` import path (F6).
- No false claims at any severity.

## Limitations

- The fixtures were too easy for Sonnet: 54/54 detections leave no headroom to
  show a skill's effect on recall. A discriminating follow-up needs subtler
  bugs (cross-file invariants, concurrency, bugs whose symptom is outside the
  diff and not named in it) and larger diffs with more distraction.
- n=2 per cell; the severity differences above are one run each.
- Reviewers read the skill from a path, so this measures content, not routing.
- Grading was keyword-screened then checked by hand by the same author who wrote
  the fixtures; no second rater.
