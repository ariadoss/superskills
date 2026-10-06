# PREREG — Codex testing philosophy in /write-plan's verification guidance

Registered before any run of the `writeplan-test-strategy` case.
Provenance: Codex's base prompts (gpt_5_2_prompt.md "Validating your work"
at 062439b) teach three rules we never shipped: verification starts as
specific as possible then broadens; do not add tests to codebases with no
tests; bound formatting/repair iterations (3 attempts, then report).
Host-agnostic by construction (markdown skill-body edit).

## Intervention (applied only between the two runs)

`skills/write-plan/SKILL.md`, new short guidance immediately after the
Test Plan & Verification template block: order verification specific →
broad; match the codebase's testing culture (never introduce a test
framework into a repo with no tests — plan dry-runs, one-off scripts, or
exact manual commands instead); bound repair loops in the plan (at most 3
iterations, then report the residue).

## Cases

| Case | Role |
|---|---|
| `writeplan-test-strategy` (new) | primary: no framework imposed on a test-less repo; specific-first + bounded verification |
| `writeplan-plan-quality` | guard (must not regress ≥ 0.34) |

**Amendment after calibration, before any comparative run (the 2026-10-04
precedent):** the first baseline ($0.65) calibrated the original prompt
("my dotfiles repo…") and found write-plan fired 0/3 — the known
under-firing on casual product asks (2026-10-04 report: 0/3 on greenfield
asks vs 3/3 infrastructure-flavoured). With the skill absent the
intervention is unmeasurable (specific-first 0/3 on plugin-less plans
confirms headroom exists). The prompt is rephrased infrastructure-flavoured
("our ops repo…", identical no-tests constraint, identical ask) and the
calibration re-run; the comparative arms start only after the rephrased
case fires ≥ 2/3. No intervention has been applied at amendment time; no
comparative data exists.

## Fairness rule (fixed in advance)

The case prompt states the no-tests constraint in the USER's voice (both
arms identical); graders grade the verification strategy's shape, never
vocabulary lifted from the skill. skill-fired is an unscored indicator.

## Endpoints and thresholds (set before the runs)

- Planning runs measured $1.00–1.53; 2 cases × 3 runs × 2 arms = 12 runs →
  each command capped `--max-cost-usd 8`; abort if any command exceeds it.
- **Firing-power gate:** write-plan fires ≥ 2/3 runs per arm on the new
  case, else under-powered → adopt nothing.
- **Primary:** mean of the two llm graders on `writeplan-test-strategy`.
- **Adopt** if primary improves ≥ +0.10 AND neither grader individually
  regresses AND the guard holds within 0.34 AND the firing gate holds.
- **Reject** otherwise: revert, keep the case, report the null.
- Stated limits: n=3/arm; one run = 0.333 of any grader; same-day drift.
