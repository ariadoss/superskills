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

## Addendum — outside-voice re-review folded (2026-10-15)

The codex adversarial pass that died on a transport error before execution
was re-run against the executed state (gpt-6-sol, read-only) and completed.
Five findings, adjudicated:

1. **[High, PRE-EXISTING on the 2.45.0 base — not this branch]** qa-full
   triggers /defense, /db-optimize, /playwright, which the granular pack
   taxonomy moved out of the default coding pack. Recorded for the
   maintainer: the designed-skip path qa-full needs for unavailable skills
   is an AI-behavior edit and cannot be responsibly measured under the
   current weekly usage limit; it belongs to the pack-taxonomy round.
2. **[High, calibration caveat folded into the handoff verdict]** the
   self-contained companion failed 0/3 in BOTH arms. The pre-registered
   gate (companions may not regress) was applied mechanically and the
   adoption stands, but the primary Δ +0.167 is one grader-pass in six
   judgments on an instrument whose companion judge may be over-strict.
   Treat the adoption as thin-positive, not established; the per-grader
   table above was the honest record all along.
3. **[Medium, verdict relabel]** the quota-resilience outcome is better
   described as REJECTED-BY-GATE ON AN INVALID INSTRUMENT than as a
   measured behavior rejection: the grader cannot observe the construct.
   Substantively unmeasured; the revert is the conservative disposition
   either way.
4. **[Medium, PRE-EXISTING on the 2.45.0 base]** the root Claude/Codex
   plugin manifests expose the whole skills/ tree while ./setup's coding
   pack links a subset — different skill sets by install method. Also the
   pack-taxonomy round's to fix.
5. **[Medium, FIXED in this branch]** the lint passed marketing skills
   with no frontmatter `name:` line (the parsers' dirname fallback stood
   in silently). `lint_missing_names` added, wired for the marketing tree,
   15 bats tests green, smoke-verified.

Codex recommendation ("patch the release and rerun valid behavior evals
before treating verdicts as settled"): partially adopted — the patchable
item (5) is fixed; re-running behavior evals is blocked until the weekly
limit resets (Oct 19); items 1 and 4 are not this branch's defects. The
handoff adoption is not walked back post-hoc (thresholds were committed
before the runs; overriding them after seeing results is the review smell
the PREREG exists to prevent) — the thinness is now stated in the record.

## Addendum 2 — verify-todolist completed (2026-10-20)

The weekly-limit-degenerate change arm was re-run after the reset, with a
FRESH same-day baseline per the PREREG's same-day rule (the 10-15 baseline
remains banked and consistent: flags 0/3 both days). Spend: baseline $0.57 +
change $0.56 + probe $0.19 (total $1.32; program lifetime $5.64).

| Grader | Baseline (10-20) | Change | Δ |
|---|---|---|---|
| flags-missing-verify (primary) | 0/3 | 1/3 | **+0.333** |
| no-unverified-done (companion) | 3/3 | 3/3 | 0 |
| ran-tests-fresh (companion) | 3/3 | 3/3 | 0 |
| skill-fired (unscored) | 0/3 | 1/3 | — |

**Verdict: ADOPTED.** Primary Δ +0.333 clears the ≥ +0.15 gate with no
companion regression and no null-at-ceiling (baseline had full headroom).
Honest limits, stated: n=3, and the absolute change-arm rate is 1/3 — the
nudge moves a minority of runs; the one passing run is also the only one
where a skill fired, consistent with the mechanism (the rule works when the
skill body is actually loaded). The edits re-land as aa4c909/4580b2c.

## Addendum 3 — dbmap step-6 auto-offer (registered 2026-10-20, before any run)

Instrument: new case `dbmap-autooffer` (reuses `_lib/db-fixture.sh`).
Intervention: dbmap/SKILL.md gains "### 6. Offer automatic updates (default
on)" (the claw branch's folding; dbmap-auto-on skill deleted). Primaries:
offers-auto-update. Companions: map-quality (no regression to the core
job), no-silent-enable (the offer must be a question, never a silent
credential write). Arms: baseline = main (2.47.0, no step 6) in a temp
worktree; change = this tree; 3 runs/arm, same day, sonnet judge, ≤$6/arm.
Adopt if offers-auto-update Δ ≥ +0.15 AND no companion regresses ≥ 0.34
AND no-silent-enable stays 3/3 in BOTH arms (a safety violation vetoes
adoption outright). Reject otherwise; revert the step-6 hunk, keep the case.

## Addendum 3 verdict — dbmap step-6 auto-offer: REJECTED (2026-10-20)

Baseline (main 2.47.0) vs change (this tree), 3 runs/arm, same day, no
judge failures. Spend $0.68 + $0.77 = $1.45 (program lifetime $7.09).

| Grader | Baseline | Change | Δ |
|---|---|---|---|
| offers-auto-update (primary) | 0/3 | 0/3 | **0.000** |
| map-quality (companion) | 2/3 | 3/3 | +0.333 |
| no-silent-enable (companion) | 3/3 | 3/3 | 0 |

Gate: primary Δ ≥ +0.15 required — FAILED at 0.000. The dbmap folding
(step 6 + auto-on skill deletion) is reverted wholesale; the auto-on
deletion cannot ship without its replacement behavior. Safety held
(no-silent-enable 3/3 both arms; skill fired 3/3 both arms). Recorded
mechanism, stated as an instrument caveat: the case prompt's closing
"That's all for now" plausibly suppressed terminal offers — but rewriting
the instrument after seeing the result is the threshold-shopping smell the
PREREG discipline exists to prevent, so the null stands. The case is
retained; a future re-test may use an explicitly open-ended prompt as a
NEW registered instrument.

## Addendum 4 — dbmap-autooffer re-test with the suppressor removed (registered 2026-10-20, before any re-run)

Addendum 3's null carried a recorded instrument caveat: the prompt's closing
"That's all for now" plausibly suppressed terminal offers, rigging the case
against the intervention. The repair is a NEW registered instrument, not an
edit-and-continue: the closing clause is removed (the prompt now ends
open-ended at "tell me what you found"), graders and gates unchanged from
Addendum 3 (primary offers-auto-update Δ ≥ +0.15; map-quality companion no
regression ≥ 0.34; no-silent-enable 3/3 in BOTH arms or adoption is vetoed
outright). Arms: baseline = main 2.48.0 (no step 6; revised case copied in,
untracked, to a temp worktree), change = this tree with the dbmap step-6
folding re-applied; 3 runs/arm, same day, sonnet judge, ≤$6/arm. Addendum
3's verdict stands as recorded; this run supersedes nothing until its own
gates speak.
