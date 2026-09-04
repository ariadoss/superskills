---
name: qa-full
version: 2.0.0
description: |
  Full per-feature QA pipeline: audit → fix → verify. Runs the complete
  multi-dimensional fan-out (tests, correctness, security, DB, frontend perf,
  browser QA, design, accessibility, coverage) scoped to the current branch's
  diff, FIXES what each check finds, re-verifies the fixes, then emits a
  pass/fail ship-readiness verdict on the repaired branch. Run it when a
  feature is finished, before /finish-branch and /ship. Use when asked to
  "run full QA", "qa-full", "feature done — check it", "is this ready to
  ship", "pre-ship check", "full quality gate", or "fix everything before
  ship".
triggers:
  - run full qa
  - qa full
  - feature done check it
  - is this ready to ship
  - pre-ship check
  - full quality gate
  - fix everything before ship
argument-hint: '<optional: base branch (default auto-detect) or --scope <paths>>'
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - Task
  - WebFetch
  - AskUserQuestion
---

# /qa-full

The per-feature QA **pipeline**. Where `/daily-qa` is the unattended, repo-wide,
time-windowed **background** sweep that only *reports*, `/qa-full` is the
**present-human, branch-scoped, audit → fix → verify** pipeline you run the
moment a feature is done — before `/finish-branch` and `/ship`.

```
implement → /qa-full → /finish-branch → /ship
            (audit → fix → verify)
```

It reuses `/daily-qa`'s trigger matrix (which checks to run based on what
changed) with three deliberate differences:

- **Scope is the branch diff** (`base..HEAD` + working tree), not a time window.
- **It fixes, not just reports.** Every check runs in three phases — **audit**
  (report-only discovery is fine here), **fix** (apply the smallest correct fix,
  one atomic commit per fix), **verify** (re-run the same check plus the test
  suite and prove the fix holds). The final verdict is on the *repaired* branch.
- **Interactive checks actually run.** Because a human is present, the checks
  `/daily-qa` only *recommends* — `/qa`, `/web-perf`, `/design-review`, the
  dynamic `/a11y` pass — run here when their triggers fire.

This is not an audit skill. It is a full security pipeline, a full performance
pipeline, a full correctness/test pipeline, and a full browser/design pipeline,
selected per-diff and driven to green.

## Hard rules

- **The bar is the superskills quality standard** — TDD/DRY/SOLID/YAGNI
  (applied in every step's fix phase: test first, no duplicated logic, small
  single-purpose units, nothing speculative) plus the hard-gate list, which is
  spelled out in full in Step 10's Blocker set. The canonical written copy is
  `ENGINEERING_STANDARDS.md` in the superskills install (a plugin install exposes
  it at `${CLAUDE_PLUGIN_ROOT}/ENGINEERING_STANDARDS.md`); it is **not** expected
  to exist in the project you're reviewing, so don't flag it as missing. Every
  fix you land must meet that bar too — a fix that adds untested public surface
  or duplicates logic is not a fix.
- **Audit → fix → verify, per check.** For every check whose trigger fires:
  1. **Audit** — run the sub-skill (its normal report-only output is the
     discovery pass).
  2. **Fix** — for each CRITICAL/HIGH finding (and MEDIUM where the fix is
     small and safe), root-cause it (`/debug` discipline: no symptom patches),
     write the failing test first when it's a logic bug (`/tdd`), apply the
     smallest correct fix, and commit it atomically with a message naming the
     check and finding.
  3. **Verify** — re-run the *same* sub-skill on the diff and re-run the test
     suite. A fix is only "fixed" when the re-audit no longer reports it and
     tests are green. Never claim a fix without this fresh evidence (`/verify`
     discipline).
  A finding you could not fix (needs a product decision, external service,
  credentials, or an architectural change beyond the diff) is an **UNFIXED
  blocker**: record what you tried and why it's out of reach. Do not quietly
  downgrade it to a warning.
- **Fix only what the diff and the findings justify.** Do not refactor
  untouched code, upgrade dependencies, or "improve" unrelated modules while
  you're in there. Scope stays on the branch diff plus the exact lines a finding
  points at.
- **Commit, but never push or open a PR.** Each fix lands as its own commit on
  the current branch so the user can review/revert individually. Integration and
  shipping belong to `/finish-branch` and `/ship`.
- **Ground every finding and every fix in concrete evidence**: file:line,
  failing test name, log snippet, severity as the underlying tool produced it,
  and the commit SHA of the fix. No speculation.
- **Separate blockers from warnings.** Only test/build failures and
  CRITICAL/HIGH findings block. Everything else is a warning — fix it when the
  fix is cheap and safe, otherwise ship it with a follow-up note.
- **Bounded loops.** At most **two** fix rounds per check, then one final
  verification pass (Step 10). If something is still red after that, it's an
  UNFIXED blocker with the attempts documented — not a third round.
- **Never claim SHIP-READY without receipts.** The verdict must cite the exact
  checks that ran, what they found, what was fixed (with commits), what was
  re-verified, and what was skipped (and why).
- **No silent skips — mandatory accounting.** Every check must resolve to
  exactly one of: **RAN-CLEAN** (ran, nothing to fix), **FIXED(n)** (ran, n
  findings fixed and re-verified — list commits), **UNFIXED** (ran, at least one
  blocker could not be fixed — reason), **SKIPPED** (stated reason — e.g. "no
  reachable dev server and none could be started", "scanner not authorized in
  this env"), **NOT-TRIGGERED** (its diff trigger didn't fire), or
  **MANDATORY-FAIL** (a `CLAUDE.md`-mandatory check that was skipped). A check whose
  trigger fired but that neither ran nor was explicitly skipped-with-reason is an
  **unaccounted check ⇒ NOT READY**. "Recommend-only" is not an allowed resting
  state for a *triggered* check. Projects may mark specific checks **MANDATORY**
  in `CLAUDE.md` (e.g. `/pentest` on a payments service), and for those, SKIPPED
  is itself a blocker.
- **Money and authorization still need a human yes.** `/code-review ultra` is a
  billed cloud run — ask before launching it, never assume. `/pentest` requires
  the user to confirm authorization before it scans — ask, then run. "Ask, then
  run" is still running; it is not report-only.

## Project configuration (`CLAUDE.md`)

This pipeline reads the project's root `CLAUDE.md` for a few optional settings.
They are plain prose (CLAUDE.md is agent instructions, not a config file) — look
for a `## qa-full` section and honor whatever it states. Example:

```markdown
## qa-full

- Mandatory checks (must RUN with evidence — a skip is a blocker): `/pentest`, `/defense`
- Hard perf gate: LCP ≤ 2.5s and INP ≤ 200ms on `/` and `/checkout` (breach blocks)
- Design: skip `/design-review` (design is owned by the design team, do not auto-fix visuals)
- Dev URL: http://localhost:3000   (for `/web-perf`, `/qa`, `/a11y`, `/fuzz`)
- Test/build: `pnpm test` and `pnpm build`
- QA tier: exhaustive
```

Recognized settings (all optional; absence = the defaults in the steps below):
- **Mandatory checks** — listed commands must read RAN-CLEAN or FIXED in the
  ledger; SKIPPED is a blocker (any step; Step 10 enforces it). MANDATORY
  overrides the check's own diff trigger: run it on the diff even when the
  trigger didn't fire, so NOT-TRIGGERED is not an acceptable state either. Use
  for compliance-critical surfaces (payments, auth, PII).
- **Hard perf gate** — turns a `/web-perf` budget breach that survives the fix
  round from a warning into a blocker (Step 6).
- **Design: skip `/design-review`** — opt *out* of the visual-fix pass (Step 8)
  entirely; by default it runs on any UI change. This skips the check (ledger:
  SKIPPED("project opt-out")) — it does not turn it into a report-only run.
- **Test/build commands** — feed Steps 2 and 10. **Dev URL** — feeds Steps 4
  (`/fuzz`), 6, 7 and 8. **QA tier** — feeds Step 7; defaults to `standard`.

If there is no `## qa-full` section, run with the built-in defaults — nothing here
is required.

## Step 1: Establish the diff scope and a clean tree

1. Detect the base branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`,
   else `git symbolic-ref refs/remotes/origin/HEAD`, else fall back to `main`/`master`.
2. If `$ARGUMENTS` names a base branch or `--scope <paths>`, use it.
3. Compute the changed-file set: `git diff --name-only <base>...HEAD` plus
   uncommitted changes (`git status --porcelain`). This set drives every
   trigger below. **Fix commits made by this pipeline extend the set** — later
   steps and the final pass (Step 10) audit the fixes too.
4. **Clean-tree precondition.** The fixers (`/qa`, `/design-review`) need each
   fix to be its own atomic commit, so they stop on a dirty tree. Handle it
   once, here: if `git status --porcelain` is non-empty, ask the user (via
   AskUserQuestion) whether to **commit the in-progress work now** (recommended
   — a descriptive commit so the feature is preserved before fixes land) or
   **stash it**. Do not proceed with a dirty tree.
5. Record at the top of the report: base branch, commit range, changed-file
   count, and the HEAD SHA before any fixes.

If there is no diff against base, stop and say so — there is nothing to QA.

## Step 2: Tests & build (always — audit → fix → verify)

1. Find the project's test/build commands from `CLAUDE.md`; if absent, infer
   from `package.json` scripts, `Makefile`, `pyproject.toml`, etc. If you
   cannot determine them, **ask** rather than guess.
2. **Audit:** run the test suite and the build. Capture exact failures (test
   name + verbatim error in a code block).
3. **Fix:** for each failing test or build error, follow `/debug` — reproduce,
   root-cause, then fix the cause (not the assertion). Commit each fix.
4. **Verify:** re-run the full suite and build. Green ⇒ FIXED(n). Still red
   after two rounds ⇒ UNFIXED blocker with the failing test and what was tried.

If this step ends UNFIXED after two rounds, **stop here** and report NOT READY
with the failing test. Every later step's verify phase depends on a green
suite — running fixers on a red suite is fix → hope, not fix → verify. Mark
every downstream ledger row `SKIPPED("pipeline halted at Step 2")`.

## Step 3: Correctness — `/code-review --fix` + `/simplify` (always)

1. **Audit:** run `/code-review` scoped to the diff (`base..HEAD`) at the
   `high` tier (pre-ship deserves the broader pass).
2. **Fix:** apply the findings — `/code-review --fix` for correctness bugs, then
   `/simplify` for the reuse/simplification/efficiency/altitude cleanups on the
   changed code. Every logic fix gets a test that would have caught it
   (`/tdd`). Commit atomically.
3. **Verify:** re-run `/code-review` on the diff (now including fix commits)
   and the test suite. CRITICAL/HIGH that survive ⇒ UNFIXED blocker.

`/code-review ultra` (deep multi-agent cloud review) is **billed** — when a
finding is high-stakes (payments, auth, data loss, concurrency), ask the user
whether to launch it. Do not launch it unasked.

## Step 4: Security pipeline — `/defense`, `/iac-scan`, `/pentest`, `/fuzz`

**`/defense` (always).**
1. **Audit:** run `/defense` scoped to the changed files (OWASP Top 10 /
   secrets / auth / crypto / data-protection).
2. **Fix:** remediate every CRITICAL/HIGH (and cheap MEDIUMs): remove or
   rotate-and-externalize hardcoded secrets, add the missing authz check,
   parameterize the query, escape the output, switch the weak primitive, add
   the validation. Each fix gets a regression test where a test can express it
   (e.g. "unauthenticated request to X returns 401"). Commit atomically.
3. **Verify:** re-run `/defense` on the same files; the finding must be gone.

**`/iac-scan` (when infra/deploy config changed).** Trigger on `Dockerfile`,
`docker-compose*`, `*.tf`/`*.tfvars`, k8s/Helm manifests, `.github/workflows/**`,
`.gitlab-ci.yml`, `Jenkinsfile`, nginx/cloud config (see `/iac-scan`'s trigger
section for the authoritative list). Audit with the local static linters, **fix**
CRITICAL/HIGH misconfigs (root container → non-root user, `0.0.0.0/0` ingress →
scoped CIDR, wildcard IAM → least privilege, privileged pod → dropped, untrusted
CI trigger → pinned/guarded, baked-in secret → injected), re-scan to verify.

**`/pentest` (triggered when `/defense` found CRITICAL/HIGH, or the diff touches
auth/crypto/session/token/deserialization/file-upload paths).** It is an external
scanner: **confirm authorization with the user first** (the skill's own
questions), then run it. Fix CRITICAL/HIGH it surfaces, re-scan to verify. If the
user declines or the scanner is unavailable ⇒ SKIPPED(reason). If `CLAUDE.md`
marks `/pentest` MANDATORY, SKIPPED is a blocker.

**`/fuzz` (triggered when the diff adds or changes endpoints, input parsing,
file-upload handling, or deserialization).** Needs a running target: find the dev
URL (`CLAUDE.md`, or start the `dev` script). Run `/fuzz` against the new
surface; **fix** crashes, injections, and auth bypasses it surfaces (with a
regression test); re-fuzz to verify. No reachable target and none startable ⇒
SKIPPED(reason). If `CLAUDE.md` marks `/fuzz` MANDATORY, SKIPPED is a blocker.

**`/cso` backstop.** If the diff crosses a *new* trust boundary (new auth
path/endpoint/external input/deserialization) and there's no evidence a threat
model was done at plan time, run `/cso` on that boundary and fold any
CRITICAL/HIGH into the `/defense` fix round. Threat modeling belongs in
`/write-plan`; this is the late catch, not a substitute.

## Step 5: Database pipeline — `/db-optimize` (auto-run if triggered)

Trigger when changed files match ORM models, migrations, query builders
(`**/models/**`, `**/migrations/**`, `**/queries/**`, `**/*repository*`,
`**/*.sql`), raw SQL in the diff, or new ORM calls (`.find`, `.where`,
`.includes`, `.join`, `.preload`).

1. **Audit:** run `/db-optimize` scoped to matched files (run `/dbmap` first if
   it asks for a schema map).
2. **Fix:** N+1s on hot paths → eager-load/batch (`includes`/`preload`/
   `select_related`/dataloader); missing indexes on hot paths → add a migration
   for the index; obviously-redundant queries → dedupe. Add a test that asserts
   the query count where the ORM supports it. Commit atomically.
3. **Verify:** re-run `/db-optimize`; the hot-path findings must be gone and
   the migration must apply cleanly in the test run.

Non-hot-path suggestions are warnings (fix if trivial). No trigger ⇒
NOT-TRIGGERED.

## Step 6: Frontend perf pipeline — `/web-perf` (+ `/perf-profile`)

Trigger when the diff includes frontend code (`**/*.tsx`, `**/*.jsx`,
`**/*.vue`, `**/*.svelte`, `**/components/**`, `**/pages/**`, `**/styles/**`,
`**/*.css`, `**/*.scss`), new images/fonts/assets, or bundler config
(`next.config.*`, `vite.config.*`, `webpack.config.*`).

1. Find the dev URL (`CLAUDE.md`, or the `dev` script in `package.json`). A
   human is present, so **start the dev server** if it isn't running. Only if
   no app is running and none can be started ⇒ SKIPPED("no reachable dev
   server, start failed: <error>").
2. **Audit:** run `/web-perf` against the affected routes. Record Core Web
   Vitals (LCP, INP, CLS) vs. any known budget.
3. **Fix:** address the measured regressions attributable to the diff —
   render-blocking imports → defer/lazy, oversized image/font → optimize or
   preload, layout shift → reserve dimensions, long task → split/memoize.
   Commit atomically.
4. **Verify:** re-run `/web-perf` on the same routes; report before/after
   numbers.

- A budget breach that survives the fix round is a **warning** by default,
  unless `CLAUDE.md` defines a hard perf gate — then it blocks.
- **`/perf-profile`** (triggered when the diff touches hot server-side paths, the
  change is pre-launch, or `/db-optimize`/`/web-perf` point at a server-side
  bottleneck): run it against the affected endpoint/job, **fix** the localized
  bottleneck (cache, batch, move off the request path), re-profile to verify.
  Needs a representative workload — if none is available ⇒ SKIPPED(reason).

## Step 7: Browser QA pipeline — `/qa` (auto-run if triggered)

> Run **`/qa`** — the full test → fix → re-verify loop — not `/qa-only`. This is
> the check that replaces manual click-through QA, and a human is present.

Trigger when the diff includes anything a human would manually QA in a browser:
UI/frontend code, pages/routes, forms, route handlers serving HTML, API
endpoints the UI consumes, auth/session flows, or config that changes
user-facing behavior.

1. Start the dev server if needed (same URL as Step 6).
2. Run `/qa` scoped to the affected surface at the project's **QA tier**
   (`CLAUDE.md`, default `standard`: critical + high + medium). `/qa` itself does
   the audit → fix → re-verify loop with atomic commits and before/after health
   scores — let it run to completion; don't cut it off at the report.
3. Fold its before/after health score, fixed-bug list (with commits), and any
   bugs it could not fix into the ledger.

- User-facing CRITICAL/HIGH bugs that `/qa` could not fix ⇒ UNFIXED blocker.
- No reachable app and none startable ⇒ SKIPPED(reason) — and note that this
  means the feature has not been browser-tested at all.

## Step 8: Design + accessibility pipeline — `/design-review`, `/a11y`

**`/design-review` (when the diff includes UI changes, unless `CLAUDE.md` opts
out).** Run `/design-review` against the changed screens — it audits visual
consistency, hierarchy, spacing, AI-slop tells and slow interactions, then
**fixes them with atomic commits and before/after screenshots**. Let it complete.
Visual findings it can't fix are warnings, not blockers. If the project opted
out in `CLAUDE.md`, record SKIPPED("project opt-out") and move on.

**`/a11y` (when the UI change is heavy and likely to affect assistive tech —
new/changed interactive components, forms, ARIA/`role`/`tabindex`,
focus/keyboard handling, images, color/contrast, motion; see `/a11y`'s trigger
section).**
1. **Audit:** run the static pass on the diff, and the **dynamic axe pass** when
   the dev URL is reachable (it is, if Step 6/7 ran).
2. **Fix:** every CRITICAL/SERIOUS — native element over ARIA-on-a-div, missing
   label/name, unreachable-by-keyboard control, focus trap, contrast below
   ratio, missing reduced-motion guard. Commit atomically.
3. **Verify:** re-run the same pass; CRITICAL that survive ⇒ UNFIXED blocker.

Scope split: `/design-review` owns *visual* quality; `/a11y` owns WCAG /
assistive-tech correctness. They overlap on contrast — `/a11y`'s measured
contrast finding is authoritative.

## Step 9: Coverage pipeline — `/test-coverage` + `/playwright`

1. **Audit:** for each changed file (including this pipeline's fix commits),
   locate its test (sibling `*.test.*`, parallel `tests/`). Use coverage data if
   present (`coverage/`, `lcov.info`, `.coverage`); else do a structural check
   for new exported functions / branches / error paths without an assertion.
2. **Fix:** run `/test-coverage` on the diff — it writes and applies the missing
   unit tests (and integration tests where risk crosses a boundary), enforcing
   Google's Testing-on-the-Toilet practices. For **user-facing flows** with no
   e2e coverage, run `/playwright` to generate and run the e2e test so a
   regression test is left behind. Commit atomically.
3. **Verify:** run the full suite; the new tests must pass, and the structural
   check must show no new **public** surface with zero tests.

New public surface still untested after this step ⇒ UNFIXED blocker. Internal
helpers without tests are warnings.

## Step 10: Final verification pass, ledger, verdict

The fix rounds changed the branch, so verify the *whole* result once more:

1. **Fresh tests + build** on the final HEAD (Step 2 commands). Stale results
   ⇒ NOT READY.
2. **Re-audit the fix commits:** run `/code-review` (diff-scoped, `high`) and
   `/defense` over `original-HEAD..HEAD` — the fixes themselves must not
   introduce a CRITICAL/HIGH. If they did, one more fix + re-verify, then stop.
3. **Diff sanity:** `git log --oneline <base>..HEAD` — every pipeline commit
   should name its check/finding; nothing outside the diff scope was touched.

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
- `/code-review` CRITICAL/HIGH correctness finding still present (Step 3)
- `/defense` CRITICAL/HIGH security finding still present (Step 4)
- `/fuzz` CRITICAL/HIGH — crash, injection, or auth bypass — still reproducible (Step 4)
- `/pentest` CRITICAL/HIGH vulnerability still present, when it ran (Step 4)
- `/iac-scan` CRITICAL/HIGH infra misconfig still present (Step 4)
- N+1 / missing index on a hot path still present (Step 5)
- CRITICAL/HIGH browser-QA bug in a user-facing flow `/qa` could not fix (Step 7)
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
| /code-review + /simplify (Step 3) | RAN-CLEAN / FIXED(n) / UNFIXED | tier, N findings, fix SHAs |
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
| Final pass (Step 10)     | RAN-CLEAN / FIXED(n) / UNFIXED | fresh test/build + re-audit of fix commits |

> No row may be blank or "recommend" for a check whose trigger fired — that is an
> unaccounted-check blocker. `CLAUDE.md`-MANDATORY checks must read RAN-CLEAN or FIXED.

## Ask-first / follow-up commands
- `/code-review ultra` — (billed; offer when a high-stakes correctness concern remains)
- `/review` — (heavier staff-level production-readiness pass; when the change is
  architecturally significant or touches a critical path)
- `/pentest` — (if it was SKIPPED for authorization and the user now wants it)
- `/fuzz` — (if SKIPPED for lack of a target and one is now available)
- `/perf-profile` — (if SKIPPED for lack of a representative workload)
- `/finish-branch` → `/ship` — (only if VERDICT is SHIP-READY)
```

Print the verdict, the fixed count, the remaining-blocker count, and a 5-line
summary to the chat.

## Anti-patterns (do not do)

- Stopping at the report. A triggered check that found something and did not
  attempt a fix has not run `/qa-full`.
- Running `/qa-only` or `/design-audit` where `/qa` / `/design-review` are
  specified. Report-only is for discovery inside a step, never the step's end.
- Claiming a finding is fixed without re-running the check that found it and
  the test suite (fresh evidence, not assertion).
- Pushing, opening PRs, or merging — that's `/finish-branch` / `/ship`.
- Fixing outside the diff: refactoring untouched modules, bumping deps, or
  "while I'm here" changes. Every commit must trace to a finding.
- Landing a fix that itself breaks the bar — untested public surface, a
  duplicated helper, a symptom patch over an unknown root cause.
- Looping without bound. Two fix rounds per check, one final pass, then report
  what's left honestly.
- Launching a billed run (`/code-review ultra`) or an external scanner
  (`/pentest`) without the user's explicit yes.
- Declaring SHIP-READY while a check was skipped without saying which and why,
  or while any UNFIXED blocker remains.
- Running any sub-check against the whole repo instead of the diff.
- Treating MEDIUM/LOW findings as blockers (noise) or hiding CRITICAL/HIGH in
  the warnings list.

## Related commands

Reuses the trigger matrix from `/daily-qa` (see `skills/daily-qa/SKILL.md`
Step 7 for the canonical globs). Differences: branch-scoped, present-human,
and it **fixes and verifies** instead of recommending.

Auto-run (diff-scoped; audit → fix → verify):
- Tests & build — always; failures root-caused via `/debug`, proven via `/verify` (Step 2).
- `/code-review --fix` + `/simplify` — correctness + quality cleanups (Step 3).
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
- `/pentest` — external scanner; authorization confirmation, then it runs.

Follow-up (outside the pipeline):
- `/review` — staff-level production-readiness review for architecturally
  significant changes (not a substitute for Step 3's `/code-review`).

Hand-off (only when SHIP-READY):
- `/finish-branch` — choose how to integrate the work.
- `/ship` — sync, bump VERSION, changelog, PR.
