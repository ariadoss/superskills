## Related commands

Shares its db/ui trigger decisions with `/daily-qa`, both decided by the
shared `scripts/qa-triggers.sh` helper (see the "Trigger helper" block in the
core SKILL.md); the glob lists in `/daily-qa` Step 7 are only the
script-not-found fallback. Differences from `/daily-qa`: branch-scoped,
present-human, and it **fixes and verifies** instead of recommending.

Auto-run (diff-scoped; audit → fix → verify):
- Tests & build — always; failures root-caused via `/debug`, proven via `/verify` (Step 2).
- `/review` — staff-level correctness review; findings fixed by the pipeline (Step 3).
- `/basic-review` — in-tree correctness review, run in `/review`'s place when gstack is unavailable (Step 3).
- `/clean-code` — KISS/DRY/SOLID/YAGNI refactors on the diff, test-verified (Step 3).
- `/defense` — OWASP/secrets/auth/crypto; findings fixed by the pipeline (Step 4).
- `/iac-scan` — when infra/deploy config changed; misconfigs fixed (Step 4).
- `/fuzz` — when the diff adds endpoints/input parsing and a target is reachable (Step 4).
- `/cso` — backstop when a new trust boundary reached the pipeline unmodeled (Step 4).
- `/db-optimize` — when DB/ORM/SQL changed; N+1/index fixes applied (Step 5).
- `/web-perf` — when frontend changed; dev server started if needed; regressions fixed (Step 6).
- `/perf-profile` — when hot server paths changed / pre-launch; bottleneck fixed (Step 6).
- `/qa` — when anything user-facing changed; full test → fix → re-verify loop (Step 7).
- `/design-review` — when UI changed; fixes + commits visual issues (Step 8).
- `/a11y` — static + dynamic pass when heavy UI changed; findings fixed (Step 8).
- `/test-coverage` + `/playwright` — write and apply the missing tests (Step 9).
- `/tdd`, `/debug`, `/verify` — the discipline every fix in the pipeline follows.

Ask-first (need the user's explicit yes):
- `/code-review ultra` — billed multi-agent cloud review.
- `/review`'s Codex passes — OpenAI tokens; per-run yes required (Step 3).
- `/pentest` — authorization confirmation, then it runs; in-harness by
  default, clearwing modes are the billed ask-first option (Step 4).

Follow-up (outside the pipeline):
- `/code-review` / `/simplify` — Claude Code built-ins overlapping Step 3; use
  them by hand, the pipeline uses the in-tree `/review` + `/clean-code`.

Hand-off (only when SHIP-READY):
- `/finish-branch` — choose how to integrate the work.
- `/ship` — sync, bump VERSION, changelog, PR.
