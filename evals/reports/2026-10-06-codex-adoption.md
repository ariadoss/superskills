# Consolidated report — Codex prompt/workflow adoption (2026-10-05/06)

Plan: `docs/superpowers/plans/2026-10-05-codex-eval-gated-adoption.md`
(passed /plan-eng-review + codex adversarial pass; both folded pre-execution).
Branch `codex-eval-gated-adoption`, base 5400e75. Every behavioral adoption
went through a PREREG committed before its first comparative run. Total
model spend: **$29.63** (Exp A $3.23 of $19 budget; Exp B $26.40 of $45) —
the budgets were caps, not targets, and the sequential-arm design stopped
as soon as the gates were decidable.

## Verdicts

| Candidate (from /tmp/codex @ 062439b) | Outcome | Evidence |
|---|---|---|
| Review-rubric calibration → /basic-review "What earns a finding" | **ADOPTED** (1.1.0 → 1.2.0) | `2026-10-06-review-calibration.md`: primary 0.733 → 1.000 (Δ +0.267 ≥ +0.15), no grader regressed, invented findings on a clean diff 2/3 runs → 0/3, introduced-bug detection held 3/3, firing 3/3 both arms |
| Contrastive plan examples → /write-plan "Plan Quality Examples" + "Filler to avoid" | **ADOPTED (contrastive form only)** | `2026-10-06-writeplan-examples.md`: C 1.000 > B 0.889 > P 0.667; Δ(C−B) +0.111, Δ(C−P) +0.333; adopted under intent-of-the-gate reading (no-filler sub-gate unsatisfiable at ceiling — disclosed); steps-verifiable 0.667 → 1.000 |
| Positive-only plan examples | **REJECTED — measurably worse** | P − B = −0.222; steps-verifiable fell to 1/3 |
| Skills usage contract → qa-full accounting experiment | **Cut before spend** | Review verified `skills/qa-full/SKILL.md` already mandates the per-check ledger (~618) and report format (~659); nothing measurable left. Conventions section added to ENGINEERING_STANDARDS.md (inert) |
| Codex skill-eval method (shadow deterministic selectors) | **Local reduction ADOPTED** | `2026-10-06-lexical-baseline.md`: BM25 floor row 8/15 = 0.53; model beats it where it matters (writeplan slice 0.60 TPR vs 0.14) and TNR is structurally beyond a ranker; row adopted for future routing reports |
| Host-neutrality lint (no instructions for absent tools) | **ADOPTED** | `tests/skills-host-neutral.bats` + `tests/lib/host-neutral-lib.sh`; six host-exclusive tokens, `host-tool-allow:` escape; tree clean; 4 bats tests |
| Status invariants (todo discipline) | Rejected up front | Host-specific plan-tool semantics; cross-harness rule; executing-plans owns checkbox discipline |
| Strict JSON review schema | Rejected up front | YAGNI — no machine consumer |
| Compaction handoff framing | Rejected up front | quota-resilience already ships the equivalent sections |
| Tool-hygiene block, context meta-tools | Rejected up front | Host-layer, unmeasurable here |
| claw-code (`ultraworkers/claw-code`) | Nothing adopted | Self-described museum exhibit; its artifacts map to repomap / quota-resilience / Test Plan & Verification, all of which superskills has |

## The maintainer's question, answered

"Does giving AI bad examples hurt?" — At n=3 with our graders: **bad
examples alone were never tested (that arm doesn't exist); positive-only
examples hurt (−0.222); the good+bad pair beat everything (+0.111 over
baseline, +0.333 over positive-only).** The contrast, not the negativity,
appears to be the active ingredient: the filler block sharpens what the
good examples are FOR. Codex shipping both blocks in both current prompts is
consistent with this. Confidence is moderate (the C−B margin is ~2
run-flips; judge-loop guard wobbled −0.333, one flip); the report says so
and marks the adoption provisional under a letter-of-the-prereg reading.

## Repo-health flag (outside plan scope)

`tests/plugin-manifests.bats` strict `claude plugin validate` fails on the
clean base (verified by stash, and it passed earlier the same day): current
Claude CLI validation now warns about CLAUDE.md at the plugin root. The
sibling test already accepts this warning for the root plugin.json; the
marketplace path now surfaces it too. Maintainer decision needed, untouched
by this branch.

## Ship state

Both adoptions are skill-body edits, host-neutral by construction (enforced
by the new lint). VERSION 2.36.1 → 2.37.0 (new skill behavior = minor),
manifests stamped via `scripts/sync-version.sh`, README title updated. All
12 eval cases, 4 PREREGs/reports, the lint, and the lexical baseline ride in
the same branch so future runs reproduce the numbers.

## Final review round (codex read-only, post-ship-gate)

Findings and dispositions:

1. **[P1] Two manifests missed by the release commit's git add** — FIXED:
   `design-skills` and `marketing-skills` plugin.json amended into the
   release commit (7432bdf); all seven stamped manifests now at 2.37.0 at
   HEAD.
2. **[P1] Plan examples wording conflicts with task-format/granularity
   rules** — RESOLVED BY SHIPPING THE MEASURED TEXT: the adoption's
   evidence belongs to the exact C-arm text, so the attempted rewording
   ("task" vs "step" + clarifier) was reverted unmerged. Follow-up for the
   next session: apply the wording fix and spot-check with
   `claude plugin eval . --case writeplan-plan-quality --runs 3 --ablation none --trust-plugin --no-publish --scaffold --allow-tools Bash --judge-model sonnet --max-cost-usd 5 --json evals/results/spotcheck-wording.json`
   (~$3); the attempt on 2026-10-06 06:38 could not run — the eval account
   hit its session limit (resets 04:30 ET); its all-zero JSON is a harness
   artifact, not behavior, and was discarded.
3. **[P2] Lint over-promises** — FIXED: lib and bats headers now scope the
   check to exactly the six host-exclusive tokens, explicitly not a general
   host-syntax checker.
4. **[P2] skips-style grader described a nonexistent `tmp` rename** — FIXED:
   grader text corrected to the actual style bait (intermediate `value`
   variable). The 3/3 scores stand: the graded dimension (no style findings
   on a pure-style change) was present in the fixture; only the grader's
   description of the bait's name was wrong.
5. **[P2] Lexical report denominator mix (9/15 vs 1/7)** — FIXED: model
   writeplan TPR restated as 9/18 runs over the same six 2026-10-04 cases;
   ranker 1/6 on those cases; plan-quality excluded from that ratio;
   "structurally unmeasurable" softened to "forced-choice as implemented".

Deferred follow-up (not blocking): grep read-errors hidden by process
substitution after the `-r` guard in the lint lib.

## Round 2 (2026-10-06, post-qa-full): the remaining Codex candidates

| Candidate | Outcome | Evidence |
|---|---|---|
| Compaction/handoff framing → quota-resilience | **REJECTED — measured null (baseline at ceiling)** | `2026-10-06-quota-handoff.md`: handoff-selfcontained 3/3, handoff-antiredo 3/3, guard clean at baseline; +0.175 gate unreachable by construction; the original section-equivalence argument is now measurement. New permanent case kept. |
| Testing philosophy (specific→broad, no frameworks into test-less repos, bounded repair) → write-plan | **CLOSED UNMEASURED (firing gate), flat under-firing booked** (gradient claim retracted after qa-full red-team verification) | `2026-10-06-writeplan-testphilosophy.md`: 0/3 firing on every utility phrasing (personal/team/fleet; calibrations 3-4 ran double-plugin contaminated — sibling worktree registered as a second plugin, disclosed in the report and PREREG addendum; the one observed fire was the sibling copy's run, discarded) vs 3/3 same-day on the system-scale ask; intervention preserved in the PREREG; with-plugin-untriggered runs show the headroom is real (specific-first ≤ 1/3) |
| Status invariants (todo discipline) | **Rejected — unmeasurable in this harness** | Requires grading in-session plan-tool state transitions; our graders see last_message (llm) or tool-input regex (tool_used), neither can observe "never pending→completed" ordering. Host-specific semantics violate the cross-harness rule on top. |
| Tool-hygiene block (parallelize reads, no re-reads after edits) | **Rejected — unmeasurable** | "Did the model batch reads" needs turn-structure analysis the grader types cannot express; host prompts already carry this guidance where the host supports it |
| Context meta-tools (get_context_remaining, new_context, tool_search) | **Rejected — wrong layer** | Harness features; a skill cannot install a tool. The lexical-baseline row (adopted) is the transferable slice of this research |
| Approval-mode-aware validation | **Rejected — unmeasurable** | `claude plugin eval` runs under one permission configuration; the intervention's trigger (interactive vs autonomous mode) cannot vary between arms |

Round-2 spend: $7.73 total (C2 $1.65; E $6.08 = calibrations $3.45 +
discarded limit-artifact $0.17 + guard $2.46; figures reconciled from the
result JSONs by the qa-full red team after three earlier drafts
disagreed). No round-2 skill-body changes shipped — both candidates
resolved without adoption — so VERSION stays 2.37.0. Coordination note
(corrected): a sibling agent session landed /handoff on branch
`handoff-skill` mid-round; its worktree was registered as a second
superskills plugin, which contaminated E's later calibrations at RUN time
(the `--case` glob executed the sibling worktree's copy of the
test-strategy case) even though the branches share no authored-file
diff. The contamination is disclosed in E's report and PREREG; any future
eval run on this machine must check `suite.plugins` for a single root
first.
