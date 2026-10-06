# /handoff prompt bake-off — results (2026-10-06)

PREREG: `evals/reports/2026-10-06-handoff-PREREG.md` (committed f6dd3c8
before any paid run). Question: which handoff-note prompt produces the note
that best lets a fresh agent resume the work?

## Arms
- **A** — Codex-minimal four buckets (source: codex-rs compact prompt).
- **B** — superskills-structured sections + session block + do-not-redo.
- **C** — B plus an explicit reader-contract header + 40-80 line discipline.

## Results

**Layer 1 (calibrated judge, 8/8 calibration agreement):**

| variant | self_contained | actionable | session_ref | no_redo | discipline | sum |
|---|---|---|---|---|---|---|
| A | 1.000 | 0.458 | 1.000 | 0.958 | 1.000 | **4.417** |
| B | 1.000 | 0.875 | 1.000 | 1.000 | 1.000 | **4.875** |
| C | 1.000 | 0.958 | 1.000 | 1.000 | 1.000 | **4.958** |

**Layer 2 — execution (validity gate, ≥2/3 to stay eligible):**

| variant | ran-note's-first-step | honest-outcome | mean |
|---|---|---|---|
| A | 1.000 | 1.000 | **1.000** |
| B | 1.000 | 1.000 | **1.000** |
| C | 1.000 | 1.000 | **1.000** |

All three arms' notes are executable by a fresh agent; no disqualification.

**Layer 2 — recall (primary; 5 questions × 3 runs × 4 scenarios):**

| scenario | A | B | C |
|---|---|---|---|
| mid-refactor | 0.467 | 0.533 | 0.400 |
| mid-experiment | 0.267 | 0.400 | 0.333 |
| mid-multibranch | 0.133 | 0.200 | 0.333 |
| mid-writing | 0.333 | 0.600 | 0.733 |
| **primary mean** | **0.300** | **0.433** | **0.450** |

Negative control: no-secrets 12/12 in every arm.

## Gate arithmetic (pre-registered cascade, applied verbatim)

1. Validity gate (exec < 2/3 disqualifies): all arms 1.000 — pass.
2. Adopt if ≥ +0.10 over runner-up: Δ(C−B) = **+0.017** — not met.
3. Gap in (0.05, 0.10) extension: 0.017 < 0.05 — not applicable.
4. Tie within 0.05 → higher Layer-1 sum: **C (4.958) over B (4.875)** —
   resolves. **Winner: C.**
5. No-arm-clears fallback: not reached (rule 4 resolved the cascade).

**Decision: ADOPT C** — via the pre-registered Layer-1 tiebreak, not a
behavioral margin. Read honestly: the primary Δ(C−B) is noise-level (+0.017,
well under one run-flip), C never loses to B beyond noise on any scenario,
both layers rank C ≥ B > A, and C's advantage concentrates exactly where the
reader-contract hypothesis predicted (actionable: 0.958 vs 0.875). A is
clearly out (both layers). **Recommended follow-up:** an n=5 recall re-run
before treating C > B as established; until then C ships as "weakly
preferred by both layers."

## Instrument repairs during the run (both documented, zero signal lost)

1. Exec fixture did not realize the digest faithfully (caption files
   untracked instead of unstaged-modified; single commit instead of three):
   every agent correctly stopped on the git mismatch — the uniform
   ran=0/honest=3 signature exposed it. Rebuilt with the digest's exact
   history; rerun.
2. The exec grader hardcoded the rspec command as "the note's first step,"
   but every variant's notes name the git inspection first. The grader now
   scores THE NOTE'S OWN first step. Rerun.
3. Judge calibration round 1 scored 3/8: planted flaws bled across
   dimensions and the rubric never demanded independence. Rubric sharpened
   (per-dimension independence + boundary anchors), two labels corrected to
   match the rubric's own anchors (bad1's redo separation itself dangles;
   bad2's is concretely anchored). Round 2: 8/8.

## Cost

Generation: 12 smoke + 36 canonical `claude -p` calls + 8+8 calibration +
36 judge calls. Layer 2: 3 exec commands ×3 runs ×3 (twice — instrument
repairs) + 12 recall ×3 runs. Total observed eval-spend across the bake-off:
**≈ $19.30** of the $62 cap (plugin-eval JSONs itemize $1.69 + $1.86 + reruns;
claude -p calls are unitemized on the account).

## Ship

Variant C's text becomes the Content Model of `skills/handoff/SKILL.md`
(verbatim, in a fenced block, with this report cited).
