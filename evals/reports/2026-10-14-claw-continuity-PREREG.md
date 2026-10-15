# PREREG — claw-code continuity adoption (handoff / quota-resilience / verify+finish-branch)

Registered before any run of `handoff-rewrite`, `quota-resume-direct`,
`verify-todolist`. Provenance: compaction-discipline and verification-nudge
rules observed in the MIT-licensed `ultraworkers/claw-code` Rust
reimplementation of the Claude Code harness (studied 2026-10-14):
(1) re-compaction must flatten prior summaries — nesting compounds ~depth ×
overhead per cycle; (2) reads that precede the last write to a path are
obsolete; (3) post-compaction continuation resumes directly, never
acknowledges/recaps the summary; (4) a 3+ item todo list completed with no
verification item is flagged by the harness itself. All adapted in
superskills' own words.

## Intervention (applied only between the two arms)

Four SKILL.md edits, per-skill reversible:
- `skills/handoff/SKILL.md` Step 2 gains two rules: "updating this
  session's note rewrites it flat — never appends, never nests" and
  "superseded state does not travel" (reads pre-latest-write never appear
  in Context; landed items leave In flight for Done with their hash).
- `skills/quota-resilience/SKILL.md`: Phase 1 rule 3 gains a flat-fold
  sentence (merge the handoff's sections into the matching sections, never
  paste under a 'previous note' heading); Phase 2 gains step 1 "Resume
  directly" (continue with the first Next step without acknowledging,
  recapping, or prefacing the continuation).
- `skills/verify/SKILL.md` + `skills/finish-branch/SKILL.md`: the
  verification nudge — a task list completed without a verification item is
  named as a gap, the item added, run, before any completion claim or the
  finish options.

Declared UNMEASURED riders in the same adoption (docs, no instrument):
DEVELOPER_WORKFLOW delegation-contract sentence + multi-in_progress note;
ENGINEERING_STANDARDS name==dirname + description-steering conventions
(enforced mechanically by tests/skills-lint.bats, not by this A/B).

## Cases

| Case | Role |
|---|---|
| `handoff-rewrite` (new) | primary: flat-rewrite + superseded-dropped; companion: self-contained |
| `quota-resume-direct` (new) | primary: resumes-directly; companions: works-next-steps, ran-tests |
| `verify-todolist` (new) | primary: flags-missing-verify; companions: ran-tests-fresh, no-unverified-done |

## Fairness rule (fixed in advance)

Graders grade behaviour (note structure, stale state dropped, reply
opening, fresh test evidence), never vocabulary. skill-fired graders are
unscored indicators. Boundary rulings are in the grader texts, committed
before runs.

## Endpoints and thresholds (set before the runs)

- Price calibration: one `--runs 1 --ablation none` run of
  `handoff-rewrite` with `--max-cost-usd 6`. ABORT (keep cases, report the
  price) if it exceeds $5.
- Runs: `--ablation none`, 3 runs/case/arm, both arms same day, one case
  per command:
  `claude plugin eval . --case <case> --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 10 --json evals/results/claw-<case>-<arm>.json`
  Budget: ≤ $10 per case per arm (≤ $60 for three cases × two arms, plus
  the ≤ $6 price run).
- **Firing-power gates:** `handoff` fires ≥ 2/3 in BOTH arms on
  `handoff-rewrite`; `quota-resilience` fires ≥ 2/3 in BOTH arms on
  `quota-resume-direct`. Below that: under-powered, adopt nothing for that
  case's skill. `verify-todolist` has NO firing gate (verify fired 0/36
  historically; finish-branch is unmeasured) — it is behaviour-graded, and
  if baseline `flags-missing-verify` is already 3/3 the edit is rejected as
  null-at-ceiling (no headroom; thermos precedent, 2026-10-07).
- **Primaries** (mean over 3 runs, change vs baseline), one per skill edit:
  handoff → mean(flat-rewrite, superseded-dropped); quota-resilience →
  resumes-directly; verify/finish-branch → flags-missing-verify.
- **Adopt per skill edit if:** its primary Δ ≥ +0.15 AND no companion
  grader on its case regresses ≥ 0.34 AND its firing gate holds (where
  applicable). Partial adoption is expected: edits adopt or revert per
  skill.
- **Reject otherwise:** revert that skill's edit, keep cases + PREREG +
  report. A null is a real answer.
- Stated limit: n=3; same-day drift between the sequential arms is an
  uncontrolled small confound (precedent: 2026-10-06 calibration report).
