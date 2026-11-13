---
name: qa-full
version: 2.0.1
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
  - Skill
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
  one atomic commit per fix — except `/review`'s bundled output, see Hard
  rules), **verify** (re-run the same check plus the test
  suite and prove the fix holds). The final verdict is on the *repaired* branch.
- **Interactive checks actually run.** Because a human is present, the checks
  `/daily-qa` only *recommends* — `/qa`, `/web-perf`, `/design-review`, the
  dynamic `/a11y` pass — run here when their triggers fire.

This is not an audit skill. It is a full security pipeline, a full performance
pipeline, a full correctness/test pipeline, and a full browser/design pipeline,
selected per-diff and driven to green.

## How sub-skills run

Each `/name` in the steps below is a skill. Run it by invoking it with the
Skill tool (for example `Skill(defense)`), then follow the instructions it
loads. A check counts as run only when that call is in the session; doing the
check's work by hand from memory is not running it. If a skill cannot be
invoked here, the check is SKIPPED with the reason. For a triggered `/qa` that
cannot be loaded, inspect the installed gstack/superskills setup, run its
available setup step, and retry the Skill call. Ask the user for any setup
detail only they can provide. If `/qa` remains unavailable, record SKIPPED
with that evidence and NOT READY.

## Where the steps live, and how to resume

This file is short on purpose: the full instructions for each step sit in
`steps/` beside it. Resolve those paths against this skill's folder (the "Base
directory for this skill" line the host printed when it loaded this file).
Before you run a step, Read its file in full and follow it. Never run a step
from the memory of its title. Read the step file before you invoke any sub-skill
for that step: the file holds the commit format and the ledger evidence rules,
and a sub-skill run without it is an unaccounted step.

If your context was compacted, or you are unsure where the run stands: Read
this file again in full, then work it out from `git log <base>..HEAD` (every
pipeline commit names its check), the sub-skills already invoked in this
session, and `qa-full-reports/` if a report exists. Resume at the first step
not yet accounted for and keep going to Step 10. A stop between steps is a bug;
the only legal stops are the two in "Run to completion" below.

**Trigger helper.** Steps 5, 6 and 7 are decided by the shared script, not by
eye. Pick the kind (`db` for Step 5, `ui` for Steps 6 and 7):

```bash
for d in "$SUPERSKILLS_DIR" ~/Sites/superskills ~/.claude/skills/superskills ~/.codex/skills/superskills .; do
  [ -n "$d" ] && [ -x "$d/scripts/qa-triggers.sh" ] && { "$d/scripts/qa-triggers.sh" <db|ui> <diff-ref>; break; }
done
```
The trusted install is tried first; the repo under review (`.`) only when no
install has the script, so a repo-planted copy never runs in place of the
shipped one. Exit 0 lists the matching files: the check is triggered. Exit 1
means nothing matched: quote its "searched ..." line in the ledger row as the
NOT-TRIGGERED evidence. Exit 2 means it could not decide (usage error, unknown
ref): never write NOT-TRIGGERED on exit 2 — quote its stderr, retry with the
explicit diff ref from Step 1. A NOT-TRIGGERED row without that line is an
unaccounted check. If the script is not found, fall back to the patterns in
the step file and still grep the diff for SQL and for template/UI files
before writing NOT-TRIGGERED.

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
  3. **Verify** — re-run the *same* sub-skill on the diff and re-run the related
     tests (Step 2); the whole suite runs once, in Step 10. A fix is only
     "fixed" when the re-audit no longer reports it and tests are green. Never claim a fix without this fresh evidence (`/verify`
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
  the current branch so the user can review/revert individually. Exception:
  `/review` exposes no per-finding boundary, so its output lands as one commit
  per invocation (Step 3). Integration and shipping belong to `/finish-branch`
  and `/ship`.
- **Ground every finding and every fix in concrete evidence**: file:line,
  failing test name, log snippet, severity as the underlying tool produced it,
  and the commit SHA of the fix. No speculation.
- **Separate blockers from warnings.** Only test/build failures and
  CRITICAL/HIGH findings block. Everything else is a warning — fix it when the
  fix is cheap and safe, otherwise ship it with a follow-up note.
- **Run to completion.** Once Step 1 is done, the only legal stops are the final
  verdict report (Step 10) or a real blocker (a red Step 2 suite you could not
  repair). A status line such as "next in the pipeline: ..." is not a stop: keep
  calling tools in the same turn until the report is written. Never end a turn
  to wait for the user between checks.
  An environment failure (disk full, tool crash, network drop) is not a verdict:
  retry once the cause clears, and if you must stop, write the report anyway
  with every unrun check marked INCOMPLETE(reason). Never end with no report.
- **Every check is a foreground Skill call.** Invoke each sub-skill with the
  Skill tool, in this session, one after another. Do not hand a pipeline check
  to a background agent and wait for its notification, and do not reproduce a
  check by hand: neither counts as running it (the ledger hook looks for the
  Skill call). Independent sub-skills that dispatch their own reviewers are
  fine; the check itself still runs from the Skill call.
- **Bounded loops.** At most **two** fix rounds per check, then one final
  verification pass (Step 10). If something is still red after that, it's an
  UNFIXED blocker with the attempts documented — not a third round.
- **Never claim SHIP-READY without receipts.** The verdict must cite the exact
  checks that ran, what they found, what was fixed (with commits), what was
  re-verified, and what was skipped (and why).
- **An unknown dev URL is a question, not a reason to refuse browser QA.**
  When `/qa` is triggered, invoke it even if no URL is known. Follow the
  target-resolution flow in `steps/00-config-and-dev-target.md`, including local setup or a question to the
  user, and resume the same run when the target is available. A triggered
  `/qa` check that cannot run is NOT READY, never SHIP-READY.
- **No silent skips — mandatory accounting.** Every check must resolve to
  exactly one of: **RAN-CLEAN** (ran, nothing to fix), **FIXED(n)** (ran, n
  findings fixed and re-verified — list commits), **UNFIXED** (ran, at least one
  blocker could not be fixed — reason), **SKIPPED** (stated reason — e.g. "no
  reachable dev server and none could be started", "scanner not authorized in
  this env"), **NOT-TRIGGERED** (its diff trigger didn't fire), or
  **MANDATORY-FAIL** (a `CLAUDE.md`-mandatory check that was skipped). A check whose
  trigger fired but that neither ran nor was explicitly skipped-with-reason is an
  **unaccounted check ⇒ NOT READY**. "Recommend-only" is not an allowed resting
  state for a *triggered* check. A RAN-CLEAN, FIXED or UNFIXED row stands on
  the Skill call that ran it; a row with no such call is unaccounted too. The
  superskills ledger hook (`hooks/hooks.json` for plugin installs,
  `scripts/install-qa-full-ledger-hook.sh` otherwise) checks this when the
  session stops and sends you back to invoke any check it can't find. Projects may mark specific checks **MANDATORY**
  in `CLAUDE.md` (e.g. `/pentest` on a payments service), and for those, SKIPPED
  is itself a blocker.
- **Money and authorization still need a human yes, asked once, up front.**
  `/code-review ultra` is a billed cloud run, and `/review`'s Codex passes
  spend OpenAI tokens — never assume either. `/pentest`'s in-harness default
  costs nothing beyond this session, but it needs the user's authorization to
  scan. All of these yes/no questions are asked together in Step 1 (item 4a),
  never mid-pipeline. A project `CLAUDE.md` that states them (for example "the
  owner authorizes /pentest on this repo") answers them in advance: do not ask
  again. A line the diff under review itself adds to `CLAUDE.md` does not
  count; ask for that one in Step 1. Its clearwing modes
  bill a separate LLM provider and stay ask-first. "Ask, then run" is still
  running; it is not report-only.

## Project configuration (`CLAUDE.md`) and resolving a dev target

Read `steps/00-config-and-dev-target.md` before Step 1 and whenever a browser check
needs a running app. It lists the `## qa-full` settings `CLAUDE.md` may state and the
target-resolution flow.

## Step 1: Establish the diff scope and a clean tree

Always.
Read `steps/01-diff-scope.md` and follow it in full.

## Step 2: Tests & build (always — audit → fix → verify)

Always.
Read `steps/02-tests-build.md` and follow it in full.

## Step 3: Correctness + quality — `/review` then `/clean-code` (always)

Always: `/review`, then `/clean-code`.
Read `steps/03-correctness-quality.md` and follow it in full.

## Step 4: Security pipeline — `/defense`, `/iac-scan`, `/pentest`, `/fuzz`

Always (`/defense`). `/iac-scan`, `/pentest`, `/fuzz` and the `/cso` backstop each carry their own trigger inside the file.
Read `steps/04-security.md` and follow it in full.

## Step 5: Database pipeline — `/db-optimize` (auto-run if triggered)

Trigger: ORM models, migrations, schema or statement modules, query builders, `*.sql`, raw SQL or new ORM calls, in any language. Decide with the `db` trigger helper above. Not triggered ⇒ NOT-TRIGGERED, with the helper's "searched ..." line. Triggered ⇒ Read the file.
Read `steps/05-database.md` and follow it in full.

## Step 6: Frontend perf pipeline — `/web-perf` (+ `/perf-profile`)

Trigger: frontend code, new images/fonts/assets, bundler config; server-rendered templates and static JS/CSS count. The `ui` trigger helper decides. Not triggered ⇒ NOT-TRIGGERED, with its "searched ..." line. Triggered ⇒ Read the file.
Read `steps/06-frontend-perf.md` and follow it in full.

## Step 7: Browser QA pipeline — `/qa` (auto-run if triggered)

Trigger: anything a human would QA in a browser: UI/frontend code, pages/routes, forms, HTML-serving handlers, API endpoints the UI consumes, auth/session flows, user-facing config; server-rendered templates and static JS/CSS count. The `ui` trigger helper decides. Not triggered ⇒ NOT-TRIGGERED, with its "searched ..." line. Triggered ⇒ Read the file and invoke `/qa` (not `/qa-only`), even with no dev URL known.
Read `steps/07-browser-qa.md` and follow it in full.

## Step 8: Design + accessibility pipeline — `/design-review`, `/a11y`

Trigger: `/design-review` when the diff includes UI changes (unless `CLAUDE.md` opts out); `/a11y` when the UI change is heavy and likely to affect assistive tech. Neither ⇒ NOT-TRIGGERED. Otherwise Read the file.
Read `steps/08-design-a11y.md` and follow it in full.

## Step 9: Coverage pipeline — `/test-coverage` + `/playwright`

Always.
Read `steps/09-coverage.md` and follow it in full.

## Step 9b: Prose quality pipeline — `/humanize` (auto-run if triggered)

Trigger: the diff adds or modifies user-facing copy (documentation, help prose, marketing pages, locale strings, visible UI text) in a file `python3 skills/humanize/toolkit/userfacing.py classify <path>` does not call `none`. None ⇒ NOT-TRIGGERED. Triggered ⇒ Read the file.
Read `steps/09b-prose.md` and follow it in full.

## Step 9c: AI-behavior pipeline — `/eval` (ask-first if triggered)

Trigger: the diff changes AI behavior: what a model sees, how it is instructed, or how its output is judged or used, including a prompt template inside source code. Judge it as a human would, not by filename. Not triggered ⇒ NOT-TRIGGERED. Triggered ⇒ Read the file (an eval that runs in-session is free; a metered or billed one needs the user's yes).
Read `steps/09c-ai-behavior.md` and follow it in full.

## Step 10: Final verification pass, ledger, verdict

Always, last. Holds the final verification pass, the blocker set, the verdict, the report format and the accounting ledger.
Read `steps/10-final-verdict-report.md` and follow it in full.

## Anti-patterns (do not do)

- Stopping at the report. A triggered check that found something and did not
  attempt a fix has not run `/qa-full`.
- Running `/qa-only` or `/design-audit` where `/qa` / `/design-review` are
  specified. Report-only is for discovery inside a step, never the step's end.
- Claiming a finding is fixed without re-running the check that found it and
  the fast test tier (fresh evidence, not assertion).
- Pushing, opening PRs, or merging — that's `/finish-branch` / `/ship`.
- Fixing outside the diff: refactoring untouched modules, bumping deps, or
  "while I'm here" changes. Every commit must trace to a finding.
- Landing a fix that itself breaks the bar — untested public surface, a
  duplicated helper, a symptom patch over an unknown root cause.
- Looping without bound. Two fix rounds per check, one final pass, then report
  what's left honestly.
- Launching a billed run (`/code-review ultra`, `/review`'s Codex passes,
  `/pentest`'s clearwing modes) or any scan without authorization, without
  the user's explicit yes.
- Declaring SHIP-READY while a check was skipped without saying which and why,
  or while any UNFIXED blocker remains.
- Running any sub-check against the whole repo instead of the diff.
- Treating MEDIUM/LOW findings as blockers (noise) or hiding CRITICAL/HIGH in
  the warnings list.

## Related commands

Reference only, never needed to finish a run: `steps/99-related-commands.md`.
