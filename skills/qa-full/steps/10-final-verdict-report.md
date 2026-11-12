## Step 10: Final verification pass, ledger, verdict

The fix rounds changed the branch, so verify the *whole* result once more:

1. **Fresh tests + build** on the final HEAD: the **whole suite**, run here
   for the first time. The related-test runs of the fix rounds do not count.
   Red ⇒ fix the cause, re-run the related tests, then run the whole suite
   again; repeat until green or two rounds fail (UNFIXED ⇒ NOT READY). Stale
   results ⇒ NOT READY.
2. **Re-audit the fix commits:** run `/defense` scoped to the files the fix
   commits touched, and read the fix commits themselves
   (`git show original-HEAD..HEAD`) against `/review`'s checklist — `/review`
   takes no commit range, and Step 3 already re-ran it twice. When `/review`
   was unavailable, run `/basic-review original-HEAD..HEAD` for this re-audit. The fixes must not
   introduce a CRITICAL/HIGH. If they did, one more fix + re-verify, then stop.
3. **Diff sanity:** `git log --oneline <base>..HEAD` — every pipeline commit
   should name its check/finding; nothing outside the diff scope was touched.
4. **Fold back the working branch** if Step 1.5 created one: `git switch
   <base> && git merge --ff-only qa-full/<...> && git branch -d qa-full/<...>`.
   If the fast-forward fails, the base moved underneath you — stop and report;
   never force.

Then build the **accounting ledger** — a row per check, each resolved to
RAN-CLEAN / FIXED(n) / UNFIXED / SKIPPED(reason) / NOT-TRIGGERED /
MANDATORY-FAIL. **The verdict cannot be SHIP-READY while any triggered check is
unaccounted or UNFIXED.**

**Phase-5 accounting (honest scope):** `/qa-full` *is* the entry to Phase 5, so it
can only enforce the **pre-ship** half. It **cannot** verify `/finish-branch`,
`/ship`, or `/land-and-deploy` — those run *after* this pipeline, so do not claim
they're done. A passing verdict is the **hard precondition** for ship: only on
SHIP-READY do you hand off *"Proceed to `/finish-branch` then `/ship`."*

Then the verdict:

- **SHIP-READY** — zero blockers remaining **and** every triggered check
  accounted for **and** the final pass is green. List what was fixed (commits),
  warnings + follow-ups, then hand off to `/finish-branch` → `/ship`.
- **NOT READY** — one or more blockers survived the fix rounds (or a check is
  unaccounted / MANDATORY-FAIL). List each with its file:line/test-name
  evidence, **what was tried**, and what the user needs to decide or provide.
  Tell the user to resolve and re-run `/qa-full`.

Blocker set (any one ⇒ NOT READY — this is the authoritative list for the
verdict; it mirrors the superskills `ENGINEERING_STANDARDS.md` hard gates, kept
in sync by the maintainer). Each is evaluated **after** the fix rounds:
- failing test or broken build, or test/build not freshly run on final HEAD (Step 2/10)
- `/review` CRITICAL correctness finding still present (Step 3)
- `/defense` CRITICAL/HIGH security finding still present (Step 4)
- `/fuzz` CRITICAL/HIGH — crash, injection, or auth bypass — still reproducible (Step 4)
- `/pentest` CRITICAL/HIGH vulnerability still present, when it ran (Step 4)
- `/iac-scan` CRITICAL/HIGH infra misconfig still present (Step 4)
- N+1 / missing index on a hot path still present (Step 5)
- CRITICAL/HIGH browser-QA bug in a user-facing flow `/qa` could not fix (Step 7)
- triggered `/qa` SKIPPED because its skill could not be loaded or no runnable
  app was available after target resolution (Step 7); browser QA remains
  unverified
- `/a11y` CRITICAL — a control unusable by screen-reader/keyboard — still present (Step 8)
- new public surface with zero tests after `/test-coverage` (Step 9)
- a hard perf gate breach after the fix round, only if `CLAUDE.md` defines one (Step 6)
- **a triggered check left unaccounted** — neither run nor SKIPPED with a reason
- **a `CLAUDE.md`-MANDATORY check that was SKIPPED** rather than run

## Report format

Write to `qa-full-reports/<branch>-<YYYY-MM-DD>.md` (create dir; add to
`.gitignore`). Structure:

```markdown
# QA-Full — <branch> @ <YYYY-MM-DD>

Base: <base>  Range: <base>..HEAD  Changed files: N (+M from fixes)
HEAD before fixes: <sha>  HEAD after: <sha>  Fix commits: K

## VERDICT: SHIP-READY ✅ | NOT READY ⛔

### Fixed (audit → fix → verify, each with its commit)
1. <check> — <file:line> — <finding> — fixed in <sha> — re-verified by <evidence>
- (or) None needed.

### Blockers remaining (must resolve before /finish-branch)
1. <file:line> — <evidence> — <what was tried> — <what's needed from you>
- (or) None.

### Warnings (ship with a follow-up note)
- …

## Accounting ledger (RAN-CLEAN / FIXED(n) / UNFIXED / SKIPPED(reason) / NOT-TRIGGERED / MANDATORY-FAIL)
| Check | Status | Evidence / fixes / reason |
|-------|--------|---------------------------|
| Tests & build (Step 2)   | RAN-CLEAN / FIXED(n) / UNFIXED | exact command + result, fix SHAs |
| /review (Step 3)         | RAN-CLEAN / FIXED(n) / UNFIXED | N findings, fix SHAs, 2nd-run result, Codex passes on/off, base used, out-of-scope stash ref if any |
| /clean-code (Step 3)     | RAN-CLEAN / FIXED(n) / UNFIXED | KISS/DRY/SOLID/YAGNI findings, fix SHAs, deferred-with-reason |
| /defense (Step 4)        | RAN-CLEAN / FIXED(n) / UNFIXED | N findings, fix SHAs |
| /iac-scan (Step 4)       | … / NOT-TRIGGERED | infra/deploy files changed? |
| /pentest (Step 4)        | … / SKIPPED(reason) / NOT-TRIGGERED | authorized? findings? |
| /fuzz (Step 4)           | … / SKIPPED(reason) / NOT-TRIGGERED | target URL, findings |
| /cso (Step 4)            | … / NOT-TRIGGERED | new trust boundary? threat-model evidence |
| /db-optimize (Step 5)    | … / NOT-TRIGGERED | N+1 / index fixes, migration |
| /web-perf (Step 6)       | … / SKIPPED(reason) / NOT-TRIGGERED | before/after LCP/INP/CLS |
| /perf-profile (Step 6)   | … / SKIPPED(reason) / NOT-TRIGGERED | bottleneck, before/after |
| /qa (Step 7)             | … / SKIPPED(reason) / NOT-TRIGGERED | tier, health before/after, fix SHAs |
| /design-review (Step 8)  | … / SKIPPED(reason) / NOT-TRIGGERED | screens, fix SHAs |
| /a11y (Step 8)           | … / SKIPPED(reason) / NOT-TRIGGERED | static + dynamic, fix SHAs |
| /test-coverage + /playwright (Step 9) | RAN-CLEAN / FIXED(n) / UNFIXED | tests added, suite result |
| /humanize (Step 9b)      | … / SKIPPED(reason) / NOT-TRIGGERED | prose files in scope, flags fixed (SHAs), warnings carried |
| /eval (Step 9c)          | … / SKIPPED(reason: not authorized) / NOT-TRIGGERED | behavior files in scope, before/after metrics or the ask-first outcome |
| Final pass (Step 10)     | RAN-CLEAN / FIXED(n) / UNFIXED | fresh test/build + re-audit of fix commits |

> No row may be blank or "recommend" for a check whose trigger fired — that is an
> unaccounted-check blocker. `CLAUDE.md`-MANDATORY checks must read RAN-CLEAN or FIXED.

## Ask-first / follow-up commands
- `/code-review ultra` — (billed; offer when a high-stakes correctness concern remains)
- `/review` Codex passes — (OpenAI tokens; ask before enabling them for a run)
- `/pentest` — (if it was SKIPPED for authorization and the user now wants it)
- `/fuzz` — (if SKIPPED for lack of a target and one is now available)
- `/perf-profile` — (if SKIPPED for lack of a representative workload)
- `/finish-branch` → `/ship` — (only if VERDICT is SHIP-READY)
```

Print the verdict, the fixed count, the remaining-blocker count, and a 5-line
summary to the chat.
