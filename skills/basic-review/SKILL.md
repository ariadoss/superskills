---
name: basic-review
version: 1.1.0
description: |
  Read-only correctness review of pending changes, needing no external
  install: correctness, security, reliability/performance and contract risk,
  each finding cited as file:line with why it is wrong and a fix. The fallback
  when gstack's /review is unavailable (not installed, or its install is
  broken); /qa-full and /daily-qa call it automatically then. Applies a
  vendored copy of gstack's pre-landing checklist. Use when asked for
  a "basic review", a "quick review without gstack", or a review in a tool where
  /review is missing. Not for quality cleanups (use /clean-code), and not the
  first choice when /review is installed: /review goes deeper and applies fixes.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# /basic-review

A portable correctness review. It reads the diff and reports; it never edits,
stages or commits. A caller that fixes findings (`/qa-full` Step 3) applies the
fixes itself and re-runs this review to verify them.

The bar for what counts as a blocker is the superskills quality standard,
`ENGINEERING_STANDARDS.md` in the superskills install (a plugin install exposes
it at `${CLAUDE_PLUGIN_ROOT}/ENGINEERING_STANDARDS.md`). It is not expected in
the project under review.

## Scope

- With an argument, review exactly that: a range such as `origin/main...HEAD`
  (as `/qa-full` passes it), or paths.
- Without one, "pending changes" means the current branch's diff against its
  base plus anything uncommitted: `git diff <base>...HEAD` and `git diff HEAD`.
  Find the base the way `/qa-full` Step 1 does (`gh repo view` default branch,
  else `origin/HEAD`, else `main`/`master`).
- If there is nothing to review, say so and stop.

Read each changed hunk with enough surrounding code (callers, the function it
sits in, the config it reads) to judge it. Verify claims against the actual
code rather than inferring from names.

## Review

Review the pending changes in this repo. Flag issues a careful maintainer would
block on before merge, in roughly this order:

1. **Correctness:** logic errors, broken invariants, missed edge cases,
   off-by-one, races, lifetime/memory bugs, error paths that swallow failures.
2. **Security:** injection, authn/authz mistakes, secret handling, unsafe
   deserialization, unsafe defaults, TOCTOU.
3. **Reliability & performance:** blocking the wrong thread, unbounded resource
   use, accidental O(N²), retries without backoff, silent failure paths.
4. **Contract risk:** behavior changes callers rely on, silently changed
   defaults, broken backward compatibility, missing migrations.

Then apply `checklist.md` in this skill's directory (gstack's pre-landing
checklist): run its Pass 1 (CRITICAL) categories, then Pass 2, and honor its
**Suppressions** list. This skill is read-only, so ignore the checklist's
Fix-First / AUTO-FIXED instructions and its output format (use the Report format
below), and skip the items it assigns to gstack's specialist subagents or to
gstack-only markers.

For each finding cite `file:line`, explain *why* it is wrong (not what the code
does), and propose a concrete fix when one is obvious. Be calibrated: if a
finding is not high-confidence, say so or skip it.

Skip pure style, formatting, naming, and anything a linter or CI already
enforces.

## Report

One entry per finding, most severe first:

```
[CRITICAL|HIGH|MEDIUM|LOW] (confidence: high|medium) file:line
Why it is wrong: ...
Fix: ...   (or "no obvious fix")
```

CRITICAL and HIGH are what a caller treats as blockers. End with one line naming
the range reviewed and the number of findings by severity.

If you find nothing worth fixing, say so plainly: "No findings worth fixing in
<range>."

## Related

- `/review` (gstack): the full review. Prefer it when installed; it goes deeper
  and applies fixes itself.
- `/clean-code`: KISS/DRY/SOLID/YAGNI quality cleanups, which this review skips.
- `/defense`: the deeper security audit of the same diff.
