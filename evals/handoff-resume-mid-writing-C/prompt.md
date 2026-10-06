---
max_turns: 4
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [handoff, resume, C]
---

You are a fresh agent with no memory of any prior session. Below is
the handoff.md the previous session left for you. Read it and answer, in
your reply, each of these five questions with specifics:
1. What is the task's definition of done, and what proves it?
2. What is already finished (with its commit hashes / file:line)?
3. What is the single next action, as an exact command?
4. What must you NOT redo, and which known-dead approaches were tried?
5. How would you resume the original session (harness + exact command)?

--- handoff.md (verbatim) ---
# Handoff: rewrite docs/migration.md as the v2.3 migration guide @ 2026-10-06

## Session
~~~
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"
fallback: claude -c -p "<prompt>"
~~~

## Goal
docs/migration.md is a complete v2.3 migration guide. It has six sections (Overview, Preparation, Breaking changes, Data migration, Rollback, FAQ), every code sample has been run verbatim, and mkdocs builds it cleanly.

## Done
- docs/migration.md sections 1–4 (Overview, Preparation, Breaking changes, Data migration) are drafted in the working tree. **They are not committed.** No commit hash exists yet.
- The Breaking changes table in docs/migration.md was cross-checked against the v2.3 changelog, commit range `e5f0000..e7fff00`.

## In flight
- docs/migration.md, section 5 (Rollback): about half drafted. The session state recorded no line numbers, so find the section by its heading.
  - What exists: partial prose and one rollback-command code sample.
  - What is wrong: the code sample uses v2.2 flags and is **known stale**. v2.3 renamed `--rollback-window` to `--rollback-window-size`.
  - What is missing: the rest of the Rollback prose and a corrected code sample.
  - Unverified: the corrected command has not been run.
- docs/migration.md, section 6 (FAQ): not started.

## Next steps
1. Protect the uncommitted draft first: `git add docs/migration.md && git commit -m "docs: v2.3 migration guide, sections 1-4 draft"`. Never run `git checkout`/`git restore` on docs/migration.md.
2. Confirm the flag rename at its source: `git log e5f0000..e7fff00 -S'rollback-window' --oneline`, then `git show <hash>` on the match.
3. In section 5's code sample, replace `--rollback-window` with `--rollback-window-size` and update any other v2.2 flags the sample uses.
4. Finish the section 5 prose in plain language (the user asked for less jargon).
5. Run the corrected rollback command verbatim against a v2.3 install and confirm it succeeds.
6. Draft section 6 (FAQ).
7. Run every code sample in sections 1–6 verbatim. No sample has been executed yet, including those in the finished sections 1–4. Fix any that fail.
8. Build the docs: `mkdocs build --strict`. This build has never been run in this session.
9. Commit: `git add docs/migration.md && git commit -m "docs: complete v2.3 migration guide"`.

## Verify
- `mkdocs build --strict` exits 0 with no warnings for docs/migration.md.
- `grep -n -- '--rollback-window\b' docs/migration.md` returns nothing, so no v2.2 flag is left.
- Every code block in docs/migration.md has been run verbatim and succeeded.

## Do not redo
- Do not redesign the TOC. The user locked six sections: Overview, Preparation, Breaking changes, Data migration, Rollback, FAQ.
- Do not re-cross-check the Breaking changes table against `e5f0000..e7fff00`. That check is done.
- Do not redraft sections 1–4. Edit them only where a code sample fails in step 7.
- Do not trust or copy the current section 5 rollback sample. It targets v2.2.

## Context
- User preferences from this session:
  - less jargon
  - keep the tables
  - code samples must run verbatim, with no placeholders the reader has to fill in
- The v2.3 changelog lives in commit range `e5f0000..e7fff00`. It is the source of truth for flag names and breaking changes.
- The docs toolchain is mkdocs.
- Verification so far is none: no sample has been executed and mkdocs has never been run.
--- end handoff.md ---
