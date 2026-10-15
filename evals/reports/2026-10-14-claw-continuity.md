# claw-continuity A/B — analysis and verdicts

Runs executed 2026-10-15 (PREREG and cases committed 2026-10-14, before any
run; one instrument repair addendum registered 2026-10-15 before the arms:
`Skill` added to `handoff-rewrite` allowed_tools after the price run showed
the skill could not fire). `--ablation none`, 3 runs/case/arm, both arms
same day, judge `sonnet`.

**Spend: $4.32 total** — price run $0.24, baseline arm $2.18, change arm
$1.90. Caps were $6/$30/$30; actuals ran ~7× under.

## Per-case results (grader pass rates, 3 runs per arm)

| Case / grader | Baseline | Change | Δ |
|---|---|---|---|
| **handoff-rewrite** | | | |
| flat-rewrite (primary ½) | 0.667 | 0.667 | 0.000 |
| superseded-dropped (primary ½) | 0.667 | 1.000 | +0.333 |
| **primary (mean)** | **0.667** | **0.833** | **+0.167** |
| self-contained (companion) | 0.000 | 0.000 | 0.000 |
| skill-fired (unscored) | 3/3 | 3/3 | gate ✓ |
| **quota-resume-direct** | | | |
| resumes-directly (primary) | 0.667 | 0.333 | **−0.333** |
| works-next-steps (companion) | 0.333 | 0.333 | 0.000 |
| ran-tests (companion) | 1.000 | 1.000 | 0.000 |
| skill-fired (unscored) | 3/3 | 3/3 | gate ✓ |
| **verify-todolist** | | | |
| flags-missing-verify (primary) | 0.000 | degenerate | — |
| no-unverified-done (companion) | 1.000 | degenerate | — |
| ran-tests-fresh (companion) | 1.000 | 1.000 | 0.000 |
| skill-fired (unscored) | 0/3 | 0/3 | no gate (as registered) |

## Verdicts (pre-registered gates)

**handoff: ADOPTED** (commit b1e8928 stays). Primary Δ +0.167 ≥ +0.15;
companion self-contained did not regress; firing gate 3/3 both arms. The
delta is carried entirely by superseded-dropped (2/3 → 3/3): with the rule
in the body, every change-arm note moved landed work out of In flight and
dropped the pre-rewrite read from Context. flat-rewrite was already at
2/3 baseline (the model rewrites flat by default when asked to "update")
and stayed there.

**quota-resilience: REJECTED** (commit 9214da2 reverted in 992cf4e).
Primary Δ −0.333 against a required ≥ +0.15; companions flat; firing gate
held, so this is a measured rejection, not under-power. Recorded
mechanism: the construct — "the reply resumes without acknowledging or
recapping the note" — is an opening-of-turn behavior, but the grader's
`focus: last_message` sees only the final message, where the agent
(rightly) reports results with note-referencing framing ("This was the one
remaining step in the resume note left by yesterday's session"). The
change arm's finals happened to carry more such framing. The edit cannot
prove its construct through this instrument; at n=3 the delta is also
within noise, and the flat companion (works-next-steps 0.333 both arms)
says nothing broke — but the gate is the gate. A future instrument would
need first-message focus or a transcript-level grader.

**verify + finish-branch: REVERTED UNMEASURED** (af58153, f7a7468 reverted
in a56f997, fa7615e). The change arm is degenerate: the account's weekly
usage limit hit during it — run 3 errored outright ("You've hit your
weekly limit · resets Oct 19") and run 2's two llm graders threw
(judge-call failures), leaving one valid run of three. An adopt gate
cannot be evaluated on a degenerate arm, so the conservative disposition
is revert. This is NOT a null: the baseline arm is complete and banked
(flags-missing-verify 0/3 — the gap-naming construct has full headroom,
and baseline agents ran the tests 3/3 without ever naming the missing
verification item, exactly the behavior the edit targets). A post-reset
re-run of this one case's change arm (~$0.54) completes the measurement;
instruments and baseline are already in tree.

## Riders (declared unmeasured in the PREREG)

DEVELOPER_WORKFLOW delegation contract + multi-in_progress note, and the
ENGINEERING_STANDARDS conventions, ship on the strength of the mechanical
lint (13 bats tests) and docs review — no AI-behavior instrument, as
registered.

## What ships

Adopted: the handoff flat-rewrite + supersede rules; the skill-tree lint
(scripts/lint-skills.sh + lib + 13 tests); both standards conventions; the
workflow delegation contract; the README count fix; three retained
instruments (cases + PREREG + this report). Rejected/reverted: the
quota-resilience and verify/finish-branch skill edits. R1 (two-PR
arrangement) resolved moot: the spend decision landed inside this branch's
lifetime, so one release carries everything.
