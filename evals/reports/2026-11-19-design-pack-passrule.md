# Design pack replacement: pass rule (written before any run)

Question: can ten concise original design skills (new pack) replace the third-party UI design skills (old pack)?

Instrument: `scripts/design-check.py` scores a produced HTML file on 13 binary checks (12 for fix tasks, 13 for build tasks;
the build-only check is a documented aesthetic direction). Score = checks passed / checks applicable.

Arms (same task, in-session Sonnet general-purpose subagents, n=3 per arm per task):
- none: no skill, just the task
- old: the old pack's matching skills, read by the agent itself
- new: the new pack's matching skills, read by the agent itself

Note (2026-11-21): the later eval (`2026-11-21-design-pack-eval.md`) replaced the `old` arm with `up`, Claude's original design skills, after the baseline was corrected. The `old` arm here is the retired third-party pack.

Tasks: FIX (repair a page with planted defects, in place) and BUILD (greenfield page, no brand, user unavailable).

Ship rule (replace old with new):
1. new mean score >= old mean score - 0.05 on BOTH tasks (non-inferior), AND
2. new mean score > none mean score on BOTH tasks (skills must help at all), AND
3. new skill bytes read per run < old skill bytes read per run (the point of the rewrite is fewer tokens).
If rule 2 fails for old AND new, report that: the skills add nothing on this instrument.
If rule 1 fails, do not delete the old pack; revise the new skills where they lose checks and rerun once.
n=3 is small: report per-run scores, never claim a difference under 0.10 as real.

## Amendment (same day, before any upstream run)
The comparison that matters is new (concise rewrites) vs upstream (the original Claude design skills the rewrites paraphrase),
not vs the third-party pack. Arm "up" = upstream skill files read by the agent: FIX = ai-slop-check + hierarchy-rhythm-review
+ interaction-states-pass; BUILD = frontend-aesthetic-direction + interaction-states-pass + ai-slop-check.
"Old" (third-party pack) runs already collected stay as supplementary data. Rule 1 now reads: new mean >= up mean - 0.05 on both
tasks; rule 3: new bytes read < up bytes read. Rule 2 unchanged. The new arm also reads design-principles (no upstream skill file
counterpart; it paraphrases the upstream system prompt), a small handicap in bytes against new.
