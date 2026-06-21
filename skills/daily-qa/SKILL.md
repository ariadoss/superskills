---
name: daily-qa
version: 1.0.0
description: |
  Daily repo health check — scans recent commits, CI failures, dependency
  drift, performance regressions, and untested code paths. Produces a
  grounded report with evidence-only findings and minimal, scoped fixes.
  Use when asked to "run daily QA", "daily repo check", "morning standup
  for the repo", "daily health report", or "check recent commits for bugs".
triggers:
  - daily qa
  - daily repo check
  - daily repo qa
  - morning repo check
  - daily health report
  - check recent commits for bugs
  - daily ci review
argument-hint: '<optional: since timestamp, e.g. "24h", "last-run", "2026-06-01">'
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Task
  - WebFetch
---

# /daily-qa

A daily, evidence-grounded sweep across the repo: recent commits, CI signals,
dependency drift, performance regressions, and test coverage gaps. Output is
a short report with **observed** vs **suspected** clearly separated, plus the
smallest viable fixes.

## Hard rules (apply to every section)

- **Ground every claim in concrete repo evidence**: commit SHAs, PR numbers,
  file paths, diff hunks, failing test names, CI job IDs, log snippets,
  lockfile entries, benchmark numbers, or trace IDs.
- **If evidence is weak or missing, say so and skip** — do not invent
  findings, do not speculate root causes, do not guess version numbers.
- **Separate "observed" from "suspected"** in every section.
- **Prefer the smallest safe fix.** No refactors, no unrelated cleanup,
  no opportunistic renames.
- **Scope stays tight** to the changed/affected areas. If a finding requires
  broader work, flag it as a follow-up — do not expand scope inline.

## Step 1: Establish the window

Determine the time window for "recent":
1. If the user passed `$ARGUMENTS`, use it (`24h`, `last-run`, ISO date, etc.).
2. Else check `.daily-qa-last-run` at the repo root — if present, use its
   timestamp as the lower bound.
3. Else default to **last 24 hours**.

Record the resolved window at the top of the report.

After the report is written, update `.daily-qa-last-run` to the current
timestamp so the next run picks up cleanly. (Add to `.gitignore` if not
already present; do not commit it.)

## Step 2: CI failures and flaky tests

Goal: summarize CI failures in the window; group by likely root cause;
suggest top fixes. (Run this **before** the commit bug scan so the bug scan
in Step 3 can cross-reference live test/CI signal.)

1. Try, in order:
   - `gh run list --limit 50 --json databaseId,conclusion,headSha,createdAt,name,workflowName`
     and filter to the window.
   - If `gh` unavailable, look for local CI artifacts: `.github/workflows/`
     to identify jobs, then `gh` per-PR or repo-specific CI tooling
     mentioned in `CLAUDE.md`.
2. For each failed run, fetch the log of the failing step
   (`gh run view <id> --log-failed`) and extract:
   - failing test name(s) or build step
   - the actual error message (verbatim, in a code block)
   - the workflow + job + step path
3. **Flaky detection**: a test is flaky if it fails on one run and passes
   on another for the **same SHA**, or if its failure message includes
   timing/race/network strings. Cite the two runs.
4. Group findings by likely root cause (compile error, env/secret drift,
   network/flake, assertion change, snapshot stale). Mark each group
   **Observed** (proven by logs) or **Suspected** (pattern match only).
5. Suggest top 1–3 fixes, each with a concrete file path or test name.

If CI is unreachable, write: *"CI signals unavailable — skipped"* and the
reason (no `gh`, no token, no remote).

## Step 3: Recent-commit bug scan

Goal: surface likely bugs introduced in the window; propose minimal fixes.

1. `git log --since=<window> --oneline --no-merges` → list candidate SHAs and
   resolve the window's commit range (oldest..HEAD within the window).
2. **Primary engine — delegate to `/code-review`.** Run `/code-review` scoped
   to the window's diff/range at a local tier:
   - `low`/`medium` for a quick daily pass; `high` when the window is large
     (>30 commits) or touches auth/crypto/payments/data paths.
   - `/code-review` reads the diff only — no browser, no external tools, no
     auth prompt — so it is **safe to auto-run**, exactly like `/defense`.
   - The **`ultra` tier is cloud-based, billed, and user-triggered** — never
     auto-run it. Recommend it (see §7f) only when a finding here is
     high-stakes and warrants a deep multi-agent cloud review.
   Fold `/code-review`'s correctness findings into report §2.
3. **Fallback (only if `/code-review` is unavailable):** read the diff hunks
   that touch logic (skip pure docs/config-only changes unless they touch
   build/CI config) and look for concrete bug signatures only:
   - off-by-one, inverted conditions, swapped args, dropped error handling,
     unhandled null/undefined, race-prone async, accidental `await` removal,
     resource leaks, missing cleanup, regex backtracking, SQL with missing
     parameter binding, auth/permission checks removed.
4. Cross-reference findings with failing tests or CI jobs from **Step 2** — if
   a commit coincides with a new failure, escalate confidence.
5. For each finding, output:
   - **SHA + file:line** evidence
   - **Observed** (what the diff actually does)
   - **Suspected impact** (only if you can name a concrete failure mode)
   - **Minimal fix** (the smallest diff that addresses it)

If no findings appear, write: *"No bug-signature findings in window — N
commits scanned."* — do not fill space with speculation.

`/code-review` already fans out internally; only delegate a separate wide scan
to an `Explore` subagent if `/code-review` is unavailable and the window spans
>30 commits.

## Step 4: Dependency / SDK drift

Goal: detect outdated deps and propose a **minimal** alignment plan with
explicit current → target versions taken from the repo.

1. Identify package manifests + lockfiles present:
   - `package.json` / `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock`
   - `pyproject.toml` / `poetry.lock` / `requirements.txt` / `uv.lock`
   - `Gemfile.lock`, `go.mod`/`go.sum`, `Cargo.toml`/`Cargo.lock`, etc.
2. Pull **current** versions directly from the lockfile (not the manifest
   range). If no lockfile, say so and stop — do not invent versions.
3. Determine **target** versions only via a reproducible source:
   - `npm outdated --json`, `pnpm outdated --format json`,
     `pip list --outdated --format=json`, `cargo outdated`, etc.
   - If the tool is unavailable, list deps as "target unknown" and
     **do not guess**.
4. Group findings:
   - **Safe patch/minor** (no breaking changes per changelog)
   - **Minor with caveats** (deprecations noted)
   - **Major** (explicitly call out breaking-change risk + required
     migration steps; cite the upstream changelog URL only if fetched
     via `WebFetch`)
   - **SDK drift** (e.g., `@anthropic-ai/sdk`, `openai`, cloud SDKs) —
     prioritize these, list any pinned model IDs or APIs that may need
     updating.
5. Propose the **smallest viable upgrade set**: prefer one cohesive bump
   per group over many. Mark all target versions as **Suggestion** unless
   they came from an explicit upstream pin in the repo.

## Step 5: Performance / benchmark regression

Goal: compare recent changes to existing benchmarks/traces; flag regressions.

1. Look for benchmark or trace artifacts:
   - `benchmark/`, `bench/`, `perf/`, `*.bench.*` test files
   - CI artifacts containing timings, flamegraphs, or `criterion`/`pytest-benchmark` output
   - traces stored under `traces/` or referenced in `CLAUDE.md`
2. If found, diff the latest run's numbers against the previous baseline
   for files touched in the window (the changed-file list from Step 3).
   Report each regression as:
   - metric name, baseline, current, delta %, commit SHA suspected
3. If no benchmarks/traces exist for the touched code paths, write:
   *"No measurements found for: <paths>"*. Suggest 1–2 specific things
   to measure next (e.g., "add a microbench for `X.foo` — hot path
   per commit abc123"). **Do not estimate impact without numbers.**

For deeper analysis on a single hotspot, recommend the user run
`/perf-profile` or `/db-optimize`.

## Step 6: Untested-path detection

Goal: identify code paths added/changed in the window that lack tests;
draft small, focused tests.

1. For each file changed in the window, locate its test file via repo
   convention (sibling `*.test.*`, parallel `tests/` tree, etc.).
2. Use coverage data if available (`coverage/`, `lcov.info`,
   `.coverage`). If absent, fall back to a structural check: new
   exported functions / new branches in `if`/`switch` / new error paths
   without a corresponding assertion in any test file.
3. For each gap, draft **one** small test that:
   - fails on the pre-change code (cite the prior SHA)
   - passes on the current code
   - touches only the changed surface — no broad refactors of test setup
4. **Do not create PRs automatically.** If the user has a `yeet`-style
   draft-PR tool wired up, suggest the exact command; otherwise output
   the test files as a code block and let the user apply them.

If pursuing TDD-style follow-up, recommend `/tdd`. To verify a fix
actually works in the running app, recommend `/verify`.

## Step 7: Scoped deep-dives (triggered)

After Steps 2–6 produce the changed-file list for the window, decide
**per-section** whether to invoke a heavier command on the narrowed scope.
The goal is high-signal automation without daily noise.

### 7a. `/db-optimize` — auto-run if triggered

Trigger when changed files match any of:
- ORM models, migrations, query builders (e.g. `**/models/**`,
  `**/migrations/**`, `**/queries/**`, `**/*repository*`, `**/*.sql`)
- raw SQL strings introduced in the diff (`grep -E "SELECT|INSERT|UPDATE|DELETE"` on diff)
- new ORM calls (`.find`, `.where`, `.includes`, `.join`, `.preload`, etc.)
  in the diff

Action: invoke `/db-optimize` **scoped to the matched files only**.
Fold its findings into the report under §4a "DB hotspots (auto-run)".
If no trigger matched: skip silently (don't even mention it).

### 7b. `/defense` — always auto-run (basic OWASP sweep)

`/defense` is the OWASP Top 10 / secrets / auth / crypto / data-protection
review. It reads code only — no external tools, no auth prompt — so it's
safe to run on every daily-qa.

Action: invoke `/defense` **scoped to all files changed in the window**
(not the whole repo — keep it fast and signal-dense). If zero code files
changed, skip.

Fold findings into the report under §4b "OWASP / defense (auto-run)" with
severity (CRITICAL / HIGH / MEDIUM / LOW) and file:line references as
`/defense` produces them. Only include CRITICAL and HIGH in the executive
summary; MEDIUM and LOW go in the report body.

### 7c. `/pentest` — recommend only (do not auto-run)

`/pentest` uses the external [clearwing](https://github.com/Lazarus-AI/clearwing)
scanner — requires LLM provider config, network/source authorization
confirmation, and is much slower. Wrong shape for unattended daily runs.

**Recommend** `/pentest` when any of:
- `/defense` flagged CRITICAL or HIGH in §4b
- dependency manifest changes in Step 4 introduced unfamiliar packages
- auth, crypto, session, token, deserialization, or file-upload code paths
  changed in the window
- **infrastructure / deploy config** changed (`Dockerfile`, `docker-compose*`,
  `**/*.tf`, `k8s`/`helm` manifests, `.github/workflows/**`, nginx/caddy/cloud
  config) — a commonly-forgotten attack surface (exposed ports, broad IAM,
  baked-in secrets). `/iac-scan` (§7i) auto-runs the static misconfig scan and
  `/defense` (§4b) sweeps for secrets; recommend `/pentest` only as the deeper
  **live** probe when those surface HIGH/CRITICAL.

Output the exact command (`/pentest`) plus the scoped path list. User
confirms authorization and runs it themselves.

### 7d. `/qa` — recommend only (do not auto-run)

`/qa` launches a browser session and applies fixes interactively — wrong
shape for an unattended daily sweep. Instead, **recommend** it when:
- changed files include UI/frontend code (`**/*.tsx`, `**/*.vue`,
  `**/components/**`, route handlers serving HTML)
- Step 3 (bug scan) surfaced a bug-signature finding in a user-facing path
- Step 2 (CI) surfaced a failing e2e/browser test

Output the exact command the user should run, e.g.
`/qa --scope src/components/Checkout.tsx` (use the project's actual
flag/syntax — check `skills/qa/SKILL.md` if unsure).

### 7e. `/web-perf` — recommend only (do not auto-run)

`/web-perf` uses Chrome DevTools MCP to measure Core Web Vitals (LCP, INP,
CLS) and trace render-blocking resources, layout shifts, and network
dependency chains against a **live running app**. It requires the
`chrome-devtools` MCP server and a URL to hit — wrong shape for unattended
runs, but high-signal when frontend code changed.

**Trigger** — recommend when any of:
- changed files include frontend code (`**/*.tsx`, `**/*.jsx`, `**/*.vue`,
  `**/*.svelte`, `**/components/**`, `**/pages/**`, `**/styles/**`,
  `**/*.css`, `**/*.scss`, layout/routing files)
- new images, fonts, or static assets added in the diff
- `next.config.*`, `vite.config.*`, `webpack.config.*`, or other bundler
  config changed (can affect bundle size and load time)
- Step 3 (bug scan) surfaced a bug-signature in a render path or data-fetching hook

**Output** — recommend the exact command:

```
/web-perf
```

Include the list of changed frontend files so the user can scope the audit
to the affected routes. If the project has a local dev URL (check
`CLAUDE.md` or common config like `package.json` `"dev"` script), include it
as context: e.g. _"Run `/web-perf` against `http://localhost:3000` — changed
files: `src/components/Hero.tsx`, `app/page.tsx`"_.

### 7f. `/cso` — recommend only (threat-model backstop)

`/cso` is OWASP Top 10 + STRIDE **threat modeling** — a **design-time** activity
whose real home is `/write-plan`. daily-qa is post-merge, so this is only a
**backstop**: it catches a trust-boundary change that shipped without a threat
model.

**Recommend** `/cso` when a commit in the window introduces a new trust boundary
and the commit/PR shows no sign threat modeling happened:
- new auth/authz flow, new public endpoint, new external integration or webhook
- new deserialization, file upload, or handling of PII/payments/credentials
- a new service-to-service or cross-tenant path

Output the exact command and note: *"threat modeling belongs at plan time
(`/write-plan` → `/cso`) — run it now if it was skipped."* Don't recommend it for
changes that cross no trust boundary.

### 7g. `/design-audit` — recommend only (visual + accessibility), alongside `/qa`

Visual consistency, hierarchy, AI-slop tells, and **accessibility** are an
easily-forgotten layer. For any **frontend feature**, the design pass belongs
*alongside* the functional pass: recommend **`/design-audit`** (read-only visual
+ a11y audit → design plan) **together with `/qa`** (§7d, functional browser QA)
— *does it look right* + *does it work*. Trigger when changed files include UI
(`**/*.tsx`, `**/*.jsx`, `**/*.vue`, `**/*.svelte`, `**/components/**`,
`**/pages/**`, `**/styles/**`, `**/*.css`). Output both commands scoped to the
changed UI files, and pair with `/web-perf` (§7e) — together they cover
work + perf + a11y + visual.

`/design-audit` only *finds and plans* (read-only). To **fix** what it flags,
recommend **`/design-review`** as the follow-up — it edits source and commits
atomically, so the user runs it deliberately, not as part of the sweep.

### 7h. `/a11y` — recommend only (screen reader + WCAG)

Accessibility regressions are silent — they don't fail a build, they fail a
screen-reader or keyboard user. `/a11y`'s dynamic pass needs a running app (wrong
shape for an unattended sweep), so **recommend** it — but only on **heavy frontend
changes likely to break assistive tech**, not every style tweak. Trigger when the
window's UI diff touches any of:
- new/changed **interactive components** (buttons, menus, dialogs, tabs, comboboxes)
- **forms** (inputs, labels, validation/error messaging)
- **ARIA** / `role=` / `tabindex` / focus or keyboard handling (`onKeyDown`, `focus()`)
- **images/icons** (alt text) or **color/contrast** changes conveying state
- **motion / animation** (autoplay, transitions, parallax — reduced-motion)

(See `/a11y`'s trigger section for the authoritative list.) Output `/a11y` scoped to
the changed UI files, alongside the `/design-audit` + `/qa` recommendations
(§7g, §7d). Skip it for pure spacing/copy CSS changes.

### 7i. `/iac-scan` — auto-run if triggered (infra misconfig)

Trigger when changed files include infrastructure/deploy config: `Dockerfile`,
`docker-compose*`, `*.tf`/`*.tfvars`, Kubernetes/Helm manifests, `.github/workflows/**`,
`Jenkinsfile`, nginx/cloud config.

Action: invoke `/iac-scan` **scoped to the matched infra files** — it's static and
read-only (uses tfsec/checkov/hadolint/actionlint if installed, signature checks
otherwise), so it's safe to auto-run like `/defense`. Fold findings into the report
under §4c "Infra misconfig (auto-run /iac-scan)" with severity and file:line. Only
CRITICAL/HIGH go in the executive summary. If no infra files changed, skip silently.
For a deeper live probe after HIGH/CRITICAL, recommend `/pentest` (§7c).

### 7j. Other related commands — recommend only

- `/code-review ultra` — when Step 3's local `/code-review` (or a CI failure)
  surfaced a high-stakes correctness concern that warrants a deep multi-agent
  cloud review. The `ultra` tier is billed and user-triggered, so never
  auto-run it — output the exact command and let the user launch it.
- `/review` — staff-level production-readiness review; heavier and more
  architectural than the Step 3 `/code-review` pass. Recommend when a commit in
  the window is architecturally significant or touches a critical path.
- `/debug` — when Step 2 (CI) or Step 3 (bug scan) has a single high-value
  failure to root-cause.
- `/perf-profile` — when Step 5 flags a regression but lacks measurements.
- `/verify` — when a fix from this report is ready to confirm.
- `/tdd` — when expanding Step 6 coverage into a real feature.
- `/finish-branch` / `/ship` — when a fix is ready to land.

## Step 8: Report format

Write to `daily-qa-reports/YYYY-MM-DD.md` (create the directory if
needed; add to `.gitignore` if appropriate). Structure:

```markdown
# Daily QA — <YYYY-MM-DD>

Window: <from> → <to>
Commits scanned: N
CI runs scanned: N

## 1. CI failures & flaky tests
- Observed failures: …
- Suspected flakes: …
- Top fixes: …

## 2. Recent-commit bug scan (auto-run /code-review)
- Observed: …
- Suspected: …
- (or) No findings.

## 3. Dependency / SDK drift
- Safe bumps: …
- Major bumps (breaking risk): …
- SDK drift: …

## 4. Performance regressions
- Observed: …
- No-measurement gaps: …

### 4a. DB hotspots (auto-run /db-optimize)
- (only if triggered; otherwise omit section)

### 4b. OWASP / defense (auto-run /defense)
- CRITICAL: …
- HIGH: …
- MEDIUM / LOW: …
- (omit subsection only if no code files changed)

### 4c. Infra misconfig (auto-run /iac-scan)
- CRITICAL / HIGH: …
- (only if infra/deploy config changed; otherwise omit section)

## 5. Untested paths
- Drafted tests: file paths + summary
- Coverage gaps without drafts: …

## Recommended next actions
1. …
2. …

## Recommended follow-up commands
- `/code-review ultra` — (only if Step 3 found a high-stakes correctness concern)
- `/review` — (only if a change is architecturally significant / critical-path)
- `/cso` — (only if a trust-boundary change shipped without a threat model)
- `/web-perf` — (only if frontend files changed; include affected routes and dev URL)
- `/design-audit` + `/qa` — (only if UI changed; visual/a11y audit alongside functional QA)
- `/a11y` — (only if heavy UI likely to affect screen-reader/keyboard/contrast)
- `/design-review` — (to fix what `/design-audit`/`/a11y` flag; mutates + commits)
- `/pentest` — (only if /defense or /iac-scan found CRITICAL/HIGH, or auth/crypto changed — NOT on a bare infra change; /iac-scan §4c already covers that statically)
- `/qa` — (only if UI changed or e2e tests failed)
```

Print the report path and a 5-line executive summary to the chat.
Update `.daily-qa-last-run`.

## Anti-patterns (do not do)

- Listing "potential issues" without a SHA, file, log line, or version.
- Proposing a refactor because the code "could be cleaner."
- Guessing a target dep version because "x.y.z is probably current."
- Claiming a perf regression without a measurement to back it.
- Opening PRs or pushing branches as part of this command.
- Bundling unrelated fixes into one finding.

## Related commands

Auto-invoked (local, diff-only — no external tools or auth prompt, safe for daily):
- `/code-review` — the engine of the Step 3 commit bug scan (local `low`/`medium`/`high` tiers); findings populate report §2.
- `/defense` — always run on changed files (basic OWASP / secrets / auth / crypto sweep).
- `/iac-scan` — when infra/deploy config changed (static misconfig scan); findings populate §4c.
- `/db-optimize` — when DB/ORM/SQL files changed.

Recommend-only (never auto-run):
- `/code-review ultra` — deep multi-agent cloud review; billed + user-triggered. Recommend when Step 3 surfaces a high-stakes correctness concern.
- `/review` — staff-level production-readiness review; recommend for architecturally significant / critical-path changes (heavier than the Step 3 `/code-review`).
- `/cso` — OWASP+STRIDE threat modeling; design-time (home is `/write-plan`). Backstop-recommend when a trust-boundary change shipped without a threat model.
- `/pentest` — heavy external scanner (clearwing) with auth confirmation; recommend when `/defense` or `/iac-scan` finds HIGH/CRITICAL, or sensitive code paths changed (a bare infra change is handled statically by auto-run `/iac-scan` §7i — pentest is only the deeper live probe on HIGH/CRITICAL).
- `/qa` — interactive browser QA; recommend when UI changed.
- `/web-perf` — Core Web Vitals + render trace against a live app (Chrome DevTools MCP); recommend when frontend files, assets, or bundler config changed.
- `/design-audit` — read-only visual/a11y audit → design plan; recommend alongside `/qa` when UI changed.
- `/a11y` — WCAG / screen-reader / keyboard audit; recommend on heavy UI changes likely to affect assistive tech (dynamic pass needs a dev URL).
- `/design-review` — *fixes and commits* visual issues (mutates); recommend as the follow-up to apply what `/design-audit`/`/a11y` flags.
- `/debug` — root-cause investigation for a specific failure.
- `/perf-profile` — drill into a perf regression flagged in Step 5.
- `/verify` — confirm a proposed fix works in the running app.
- `/tdd` — write the failing test first when expanding Step 6 coverage.
- `/finish-branch` / `/ship` — when a fix from this report is ready to land.
