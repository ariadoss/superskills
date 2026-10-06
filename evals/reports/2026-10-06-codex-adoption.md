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
