---
name: diff-walkthrough
version: 1.0.0
description: |
  Present a changeset for comprehension: reorganize the diff by reviewer value
  (core logic first, wiring condensed, boilerplate summarized), distill dense
  hunks into pseudocode, trace surprising behavior changes on a concrete
  input, and tag the few genuinely tricky hunks. Use when asked to "walk me
  through the diff/PR", "explain what changed", or to catch someone up on a
  branch. Not a review: it explains, it does not judge — for findings use
  /review (or /basic-review), for quality use /clean-code.
triggers:
  - walk me through the diff
  - walk me through this pr
  - explain what changed
  - catch me up on this branch
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
metadata.upstream: https://github.com/cursor/plugins (pr-review-canvas/skills/pr-review-canvas, MIT)
---

# /diff-walkthrough

Present a changeset reorganized for reviewer comprehension — not in file-tree
order, not a raw diff dump. This skill explains what happened; it does not
review. Findings belong to `/review` or `/basic-review`.

## Gather the diff

Accept a branch, a range, staged/uncommitted changes, or a PR reference (with
`gh pr diff` when the remote is reachable). **If the user did not say which
changeset they mean, stop and ask.** Never guess from recent history or fall
back to a silent default — a walkthrough of the wrong diff is worse than no
walkthrough.

## Group changes for comprehension

Do **not** present files in alphabetical or tree order. Reorganize into
sections ordered by reviewer value:

1. **Core logic** — new behavior, algorithm changes, state transitions, API
   surface changes. Show the real hunks with surrounding context.
2. **Wiring & integration** — route registration, dependency injection, config
   plumbing that connects the core logic. Condensed: enough to confirm
   correctness.
3. **Boilerplate & mechanical** — renames, import reordering, generated code,
   formatting, type re-exports. Summarize as a list of files and stats; no
   inline hunks unless something is genuinely surprising there.

Lead with core logic: attention is freshest at the top.

## Distill dense logic into pseudocode

When a core hunk is dense — nested conditions, state machines, retry/backoff,
multi-step transforms — add a few lines of pseudocode next to it that strip
syntax and error handling to expose the essential control flow. Only for hunks
that are genuinely hard to scan; straightforward changes need no mirror.

## Trace surprising behavior on a concrete example

When a hunk changes behavior in a way that is hard to predict from reading it
— reordered operations, new short-circuits, altered edge cases — pick one
small, realistic input and walk it through the old and new code paths
side by side, highlighting the step where they diverge and the observable
outcome. Reserve this for genuinely surprising changes.

## Call attention to tricky things — sparingly

When a hunk hides something risky or easy to miss, mark it with a short tag
(`Subtle`, `Breaking`, `Race condition`, `Perf`) and one sentence. Overuse
destroys the signal; a few tags per walkthrough is the ceiling.

## Tone

Write reviewer-facing commentary, not a changelog: **why** it changed, how
files interact ("the new validator in core.py is invoked by the route added
in routes.py"), anything the diff alone does not make obvious. One or two
sentences per note. No findings, no verdicts, no "LGTM".

---

Adapted from [cursor/plugins](https://github.com/cursor/plugins)
`pr-review-canvas/skills/pr-review-canvas/SKILL.md` (MIT, © Cursor) — the
canvas-SDK presentation layer replaced with markdown conventions.
