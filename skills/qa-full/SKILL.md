---
name: qa-full
version: 1.0.0
description: |
  Comprehensive per-feature QA gate. Runs the full multi-dimensional quality
  fan-out (tests, correctness, security, DB, frontend perf, browser QA,
  coverage) scoped to the current branch's diff, then emits a pass/fail
  ship-readiness verdict. Run it when a feature is finished, before
  /finish-branch and /ship. Use when asked to "run full QA", "qa-full",
  "feature done — check it", "is this ready to ship", "pre-ship check",
  or "full quality gate".
triggers:
  - run full qa
  - qa full
  - feature done check it
  - is this ready to ship
  - pre-ship check
  - full quality gate
argument-hint: '<optional: base branch (default auto-detect) or --scope <paths>>'
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Task
  - WebFetch
---

# /qa-full

The per-feature QA gate. Where `/daily-qa` is the unattended, repo-wide,
time-windowed **background** sweep, `/qa-full` is the **present-human,
branch-scoped, pass/fail** gate you run the moment a feature is done — before
`/finish-branch` and `/ship`.

```
implement → /qa-full → /finish-branch → /ship
            (this gate)
```

It reuses `/daily-qa`'s trigger matrix (which checks to run based on what
changed) with three deliberate differences:

- **Scope is the branch diff** (`base..HEAD` + working tree), not a time window.
- **Output is a pass/fail verdict**, not an advisory report. CRITICAL/HIGH
  findings **block**.
- **Interactive checks auto-run.** Because a human is present, the checks
  `/daily-qa` only *recommends* (`/web-perf`, browser QA) are run here when
  their triggers fire.

## Hard rules

- **The bar is the superskills quality standard** — TDD/DRY/SOLID/YAGNI plus the
  hard-gate list, both spelled out in full in this skill (Step 10), so you do
  **not** need to open any external file. The canonical written copy is
  `ENGINEERING_STANDARDS.md` in the superskills install (a plugin install exposes
  it at `${CLAUDE_PLUGIN_ROOT}/ENGINEERING_STANDARDS.md`); it is **not** expected
  to exist in the project you're reviewing, so don't flag it as missing. Step 10's
  verdict is exactly "does the diff meet those standards."
- **This is a gate, not a fixer.** Detect and report blockers with the
  smallest viable fix; do **not** mutate source, open PRs, or push. The user
  fixes, then re-runs `/qa-full`. (For an auto-fixing flow, that's a future
  `--fix` mode — not this command.)
- **Ground every finding in concrete evidence**: file:line, failing test name,
  log snippet, severity as the underlying tool produced it. No speculation.
- **Separate blockers from warnings.** Only test/build failures and
  CRITICAL/HIGH findings block. Everything else is a warning that ships with a
  follow-up note.
- **Scope stays on the diff.** Run every sub-check against the changed files,
  not the whole repo — keep it fast and signal-dense.
- **Never claim SHIP-READY without receipts.** The verdict must cite the exact
  checks that ran, what passed, and what was skipped (and why).

## Step 1: Establish the diff scope

1. Detect the base branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`,
   else `git symbolic-ref refs/remotes/origin/HEAD`, else fall back to `main`/`master`.
2. If `$ARGUMENTS` names a base branch or `--scope <paths>`, use it.
3. Compute the changed-file set: `git diff --name-only <base>...HEAD` plus
   uncommitted changes (`git status --porcelain`). This set drives every
   trigger below.
4. Record at the top of the report: base branch, commit range, changed-file
   count, and whether the working tree is dirty.

If there is no diff against base, stop and say so — there is nothing to gate.

## Step 2: Tests & build (always — hard blocker)

1. Find the project's test/build commands from `CLAUDE.md`; if absent, infer
   from `package.json` scripts, `Makefile`, `pyproject.toml`, etc. If you
   cannot determine them, **ask** rather than guess.
2. Run the test suite and the build. Capture exact failures (test name +
   verbatim error in a code block).
3. **Any failing test or broken build is a hard blocker** — the gate cannot be
   SHIP-READY. Recommend `/verify` to confirm a fix, or `/debug` /
   `/investigate` to root-cause.

## Step 3: Correctness — `/code-review` (always, auto-run)

Run `/code-review` scoped to the diff (`base..HEAD`). Because this is a
pre-ship gate, default to a **higher local tier** (`high`) than the daily pass.
`/code-review` reads the diff only — no fix mode here (gate, not fixer).

- Fold correctness findings into the report. **CRITICAL/HIGH block.**
- The `ultra` tier (deep multi-agent cloud review, billed) is **recommend-only**
  — surface the exact command when a finding is high-stakes; the user launches it.

## Step 4: Security — `/defense` (always, auto-run)

Run `/defense` scoped to the changed files (OWASP Top 10 / secrets / auth /
crypto / data-protection). Diff-only, no external tools, no auth prompt.

- **CRITICAL/HIGH block.** MEDIUM/LOW are warnings.
- **Recommend `/pentest`** (do not auto-run — external scanner, needs auth
  confirmation) when `/defense` flags CRITICAL/HIGH, or auth/crypto/session/
  token/deserialization/file-upload paths changed in the diff.

## Step 5: Database — `/db-optimize` (auto-run if triggered)

Trigger when changed files match ORM models, migrations, query builders
(`**/models/**`, `**/migrations/**`, `**/queries/**`, `**/*repository*`,
`**/*.sql`), raw SQL in the diff, or new ORM calls (`.find`, `.where`,
`.includes`, `.join`, `.preload`). Run `/db-optimize` scoped to matched files.

- N+1s and missing indexes on hot paths are **blockers**; other suggestions are
  warnings. If no trigger matched, skip silently.

## Step 6: Frontend perf — `/web-perf` (auto-run if triggered)

> This is a key difference from `/daily-qa`, which only *recommends* `/web-perf`.
> Here a human is present and a dev server can be started, so **run it**.

Trigger when the diff includes frontend code (`**/*.tsx`, `**/*.jsx`,
`**/*.vue`, `**/*.svelte`, `**/components/**`, `**/pages/**`, `**/styles/**`,
`**/*.css`, `**/*.scss`), new images/fonts/assets, or bundler config
(`next.config.*`, `vite.config.*`, `webpack.config.*`).

1. Find the dev URL (`CLAUDE.md`, or the `dev` script in `package.json`).
   If no running app and none can be started, **downgrade to recommend-only**
   and note it in the report — do not block on an environment you can't reach.
2. Run `/web-perf` against the affected routes. Report Core Web Vitals (LCP,
   INP, CLS) vs. any known budget.
- A measured regression past budget is a **warning** by default (perf is rarely
  a hard ship-blocker) unless `CLAUDE.md` defines a hard perf gate, in which
  case treat a breach as a blocker.
- **Recommend `/perf-profile`** (do not auto-run — it needs a representative
  workload, not a diff) when the diff touches hot server-side paths, the change
  is pre-launch, or `/db-optimize`/`/web-perf` point at a bottleneck that needs
  application-level execution timing to localize. This is the app-layer
  counterpart to `/web-perf` (frontend) and `/db-optimize` (DB).

## Step 7: Browser QA — `/qa-only` (auto-run if UI changed)

> Use `/qa-only` (report-only), **not** `/qa`. A gate must not mutate source.

Trigger when the diff includes UI/frontend code or route handlers serving HTML.
Run `/qa-only` scoped to the affected surface; fold its health score and repro
steps into the report.

- Broken user-facing flows (CRITICAL/HIGH bugs in the QA report) are **blockers**.
- If the user wants the test→fix→re-verify loop instead, recommend `/qa`
  (interactive, mutates code) as a follow-up — outside this gate.

## Step 8: Design review — recommend (auto-run optional)

When the diff includes UI changes, **recommend `/design-review`** for visual
consistency, hierarchy, and AI-slop tells. This is a quality warning layer, not
a blocker. Auto-run it only if the project treats design as a gate (per
`CLAUDE.md`); otherwise output the command.

## Step 9: Coverage — untested paths

For each changed file, locate its test (sibling `*.test.*`, parallel `tests/`).
Use coverage data if present (`coverage/`, `lcov.info`, `.coverage`); else do a
structural check for new exported functions / new branches / new error paths
without a corresponding assertion.

- New **public** surface with zero tests is a **blocker** for a feature
  completion gate. Draft one focused failing-then-passing test per gap (output
  as a code block — do not apply). Internal helpers without tests are warnings.
- Recommend `/tdd` when a gap is large enough to warrant test-first follow-up.

## Step 10: Ship-readiness verdict

Roll everything up into a single gate verdict.

- **SHIP-READY** — zero blockers. List warnings + follow-ups. Hand off:
  *"Proceed to `/finish-branch` then `/ship`."*
- **NOT READY** — one or more blockers. List each blocker with its
  file:line/test-name evidence and the smallest fix. Tell the user to fix and
  re-run `/qa-full`.

Blocker set (any one ⇒ NOT READY — this is the authoritative list for the gate;
it mirrors the superskills `ENGINEERING_STANDARDS.md`, kept in sync by the
maintainer — you do not need to read that file to run this gate):
- failing test or broken build (Step 2)
- `/code-review` CRITICAL/HIGH correctness finding (Step 3)
- `/defense` CRITICAL/HIGH security finding (Step 4)
- N+1 / missing index on a hot path (Step 5)
- CRITICAL/HIGH browser-QA bug in a user-facing flow (Step 7)
- new public surface with zero tests (Step 9)
- a hard perf gate breach, only if `CLAUDE.md` defines one (Step 6)

## Report format

Write to `qa-full-reports/<branch>-<YYYY-MM-DD>.md` (create dir; add to
`.gitignore`). Structure:

```markdown
# QA-Full — <branch> @ <YYYY-MM-DD>

Base: <base>  Range: <base>..HEAD  Changed files: N  Working tree: clean|dirty

## VERDICT: SHIP-READY ✅ | NOT READY ⛔

### Blockers (must fix before /finish-branch)
1. <file:line> — <evidence> — <minimal fix>
- (or) None.

### Warnings (ship with a follow-up note)
- …

## Checks run
| Check | Status | Notes |
|-------|--------|-------|
| Tests & build (Step 2) | pass / FAIL | … |
| /code-review (Step 3)  | clean / N findings | tier used |
| /defense (Step 4)      | clean / N findings | … |
| /db-optimize (Step 5)  | ran / skipped | trigger |
| /web-perf (Step 6)     | ran / recommend / skipped | dev URL |
| /qa-only (Step 7)      | ran / skipped | health score |
| /design-review (Step 8)| recommend / ran / skipped | … |
| Coverage (Step 9)      | N gaps | drafted tests |

## Recommended follow-up commands
- `/code-review ultra` — (only if a high-stakes correctness concern)
- `/pentest` — (only if /defense found CRITICAL/HIGH or sensitive paths changed)
- `/perf-profile` — (app-level execution profiling; pre-launch or when a
  hot path / measured bottleneck needs localizing)
- `/qa` — (interactive test→fix loop, if Step 7 found user-facing bugs)
- `/design-review` — (if UI changed)
- `/finish-branch` → `/ship` — (only if VERDICT is SHIP-READY)
```

Print the verdict + a 5-line summary to the chat.

## Anti-patterns (do not do)

- Mutating source, opening PRs, or pushing — this is a gate, not a fixer.
- Declaring SHIP-READY while a check was skipped without saying which and why.
- Running any sub-check against the whole repo instead of the diff.
- Auto-running `/qa` (mutates) instead of `/qa-only` (reports).
- Blocking on `/web-perf` when no dev server is reachable — downgrade to
  recommend and note it.
- Treating MEDIUM/LOW findings as blockers (noise) or hiding CRITICAL/HIGH in
  the warnings list.

## Related commands

Reuses the trigger matrix from `/daily-qa` (see `skills/daily-qa/SKILL.md`
Step 7 for the canonical globs). Differences: branch-scoped, gate semantics,
interactive checks auto-run.

Auto-run (diff-scoped, non-mutating):
- `/code-review` — correctness (Step 3); local tiers only.
- `/defense` — OWASP/secrets/auth/crypto (Step 4).
- `/db-optimize` — when DB/ORM/SQL changed (Step 5).
- `/web-perf` — when frontend changed and a dev URL is reachable (Step 6).
- `/qa-only` — when UI changed; report-only (Step 7).

Recommend-only:
- `/code-review ultra` — deep multi-agent cloud review; billed + user-triggered.
- `/pentest` — external scanner needing auth confirmation.
- `/perf-profile` — app-level execution profiling; needs a representative
  workload, so it's a pre-launch / bottleneck-localizing follow-up, not a gate.
- `/qa` — interactive test→fix→re-verify loop (mutates code).
- `/design-review` — visual QA (unless project gates on design).
- `/verify`, `/debug`, `/investigate`, `/tdd` — per-issue follow-ups.

Hand-off (only when SHIP-READY):
- `/finish-branch` — choose how to integrate the work.
- `/ship` — sync, bump VERSION, changelog, PR.
