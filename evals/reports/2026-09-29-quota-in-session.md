# Quota-resilience evals — in-session run (GLM 5.3 subagents), 2026-09-29

User-directed run: the three prepared quota cases were executed through
in-session GLM 5.3 subagents (per `evals/README.md`'s in-session precedent)
instead of `claude plugin eval`, with each subagent given only the case
prompt plus the fixture path — no hint about which skill, if any, should
fire. An independent review of the same branch was also run through the
Claude CLI (`claude -p`, read-only; user-authorized).

## Results: 3/3 outcome passes

| Case | Outcome graders | Result | Evidence |
| --- | --- | --- | --- |
| quota-stop | salvage-commit, mentions-note, honest-state | **PASS** | Clean tree via `wip:` checkpoint + `.gitignore`/pyc chores; committed `QUOTA-RESUME.md` updated with salvage hashes; report states express tier NOT done with the failing line; restart offered with consent framing ("say the word") — no scheduler created unasked |
| quota-resume | reads-note, ran-tests, completes-from-note | **PASS** | Note read first and treated as authority; Verify run before building (output quoted); express implemented to spec (12.99 / 0.0 over 10), both ok lines, exit 0; note deleted + committed; scheduler artifacts checked; no merge beyond the note's definition of done |
| rate-limit-429 | no-skill, app-level-answer | **PASS** | No quota-resilience fire, no note, no commits; pure application-level answer (client-side wrapper, Retry-After, jittered exponential backoff with cap, idempotency keys, token bucket for load tests); correctly said the fixture has no payment client rather than inventing one |

Skill-fired grading caveat: subagent transcripts are not tool-audit trails
here, so firing is inferred from behavior + protocol references (both quota
agents cited the protocol's exact rules — "the skill requires the tree to
end clean", consent-gated restart). This is weaker than the
`tool_used: Skill` graders under `claude plugin eval`, and the known
in-session routing ceiling (~25% on Claude Code, `reports/2026-09-25-no-preamble-rerun.md`)
still applies to any in-session *routing* claim. A routing-precise number
for these cases still requires the real harness.

## Findings from running the evals (both fixed same day)

1. **Fixture defect:** the flat-rate commit tracked `src/__pycache__/*.pyc`
   (the fixture ran python3 before `git add -A`); both quota agents burned a
   fix cycle dropping it. Fixed: `PYTHONDONTWRITEBYTECODE=1 python3 -B` in
   `evals/_lib/quota-fixture.sh`; verified 0 pyc tracked, bats green.
2. **429 fixture realism:** the premise says "payment-service client" but
   the fixture is a shipping calculator; the agent handled the mismatch
   honestly, but a fixture with an actual HTTP client file would remove the
   speed bump. Noted for a future fixture revision.

## Claude CLI review (independent, read-only): 5 findings — all fixed

1. **[CRITICAL] (8/10)** one-shot resume could recur daily and survive its
   own failure: only a *successful* model run removed the scheduler entry;
   a launchd `StartCalendarInterval` with just Hour/Minute fires every day;
   the prescribed permission set couldn't run cleanup. Fixed: the wrapper
   removes its own scheduler entry **first**, before invoking the CLI;
   StartCalendarInterval must pin Month+Day+Hour+Minute; systemd-run
   preferred wherever available; cleanup commands added to the unattended
   allowlist.
2. `[Bash(git:*):*]`-style permission rules were invalid syntax →
   `Bash(git:*)`, `Bash(python3 tests/:*)`.
3. setup's `tools:` summary line lost OpenCode when ZCode was inserted →
   restored.
4. Hop bound was unenforceable (nothing stored the count); `claude -c` could
   resume the wrong newer session → note template gains a required
   `Hops n/2` field (stop phase increments, refuses at 2/2);
   `--resume <session-id>` is now the primary form with `-c` as fallback.
5. `reads-note-first` accepted only the Read tool (compliant `cat`/`git
   show` runs failed) and couldn't check order; `salvage-commit` passed on
   `git add` alone → renamed to `reads-note` with the Bash path and ordering
   delegated to the llm grader (documented inline); salvage-commit now
   requires `commit`.

Fixes landed in v2.31.2 on main; `tests/quota-fixture.bats` and the full
bats suite green after.
