# PREREG — /handoff prompt bake-off (A vs B vs C)

Registered before any generation or eval run. Question: which handoff-note
prompt produces the note that best lets a fresh agent resume the work?

## Arms
- A — Codex-minimal four buckets (source: codex-rs compact prompt @062439b,
  made file-less for generation: stdout IS the artifact)
- B — superskills-structured sections + session block + do-not-redo
- C — B plus explicit reader-contract header + 40-80 line discipline

## Method
- Generation: 4 scenarios × 3 variants × 3 runs = 36 notes via `claude -p`
  (file-less variants; fixed session-ref block embedded like-for-like).
  Plus 12 throwaway smoke cells in a separate OUT (hand-inspected, then
  discarded). claude -p exposes no per-call cap — a DISCLOSED deviation
  from the capped-command rule; the control is the driver's fixed,
  idempotent cell list plus a spend check after each batch; abort on any
  anomaly.
- Layer 1 (judge): sonnet judge scores each note 0/0.5/1 on five dimensions
  (self-contained; next-step actionability with exact commands; session/env
  reference present; do-not-redo present; length discipline). Judge
  calibration first: 8 hand-labeled artifacts — good examples in BOTH the A
  shape and the B shape (so calibration cannot bake in B's section list),
  and planted single-flaw failures covering every dimension (dangling
  reference; commandless next step; missing session block; no do-not-redo;
  a note 3x the digest's length; a confidently WRONG next command). Adopt
  the judge only if ≥6/8 agree with labels.
- Layer 2 (behavioral, decisive): 12 recall cases (4 scenarios × 3
  variants), each embedding that variant's r1 note verbatim (no run-index
  confound; note-level n=1 per scenario is a stated limit — judge-layer
  replication covers within-variant generation variance), asking 5 resume
  questions; 5 llm graders (focus last_message) + 1 no-secrets grader.
  PLUS 3 execution cases (mid-refactor fixture repo; the fresh agent
  performs the note's named next action; 2 graders: ran-the-named-action,
  honest-outcome — themselves calibrated on 2 hand-labeled replies: one
  faithful run, one plausible-action substitution). 3 runs/case,
  --ablation none, sonnet judge.

## Endpoints (fixed in advance)
- **Validity gate:** a variant failing its execution case (< 2/3 mean) is
  out regardless of recall.
- **Primary:** Layer-2 recall mean over the 5 resume-question graders, per
  variant.
- **Adopt the winner** if it beats the runner-up by ≥ +0.10 with no scenario
  regressing ≥ 0.34. Gap in (0.05, 0.10): extend the top two arms by +2
  runs/case on their recall cases (≤ $8) and re-decide at ≥ +0.10. Tie
  within 0.05 → higher Layer-1 sum → still tied → the simpler variant
  (A < B < C by complexity). **No arm clears any gate → ship variant B
  labeled "unproven default (house shape)"** — the skill needs a content
  model; the null is recorded, not hidden.
- **Negative control:** no-secrets grader must be 3/3 in every arm.
- Caps: each plugin-eval command --max-cost-usd 8; total ≤ $62.
- Limits: single-judge design (calibrated); generation/judging share the
  Claude account's rolling windows — drivers are idempotent per file and
  resume across a window reset.

## Post-experiment
The winner's text becomes the Content Model section of
skills/handoff/SKILL.md with scores cited. Losers archived in the report.
