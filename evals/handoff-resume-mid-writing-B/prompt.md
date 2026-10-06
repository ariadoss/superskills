---
max_turns: 4
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [handoff, resume, B]
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
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"
fallback: claude -c -p "<prompt>"

## Goal
docs/migration.md is a complete v2.3 migration guide. It has all six locked sections, every code sample runs verbatim against v2.3, and the mkdocs build passes.

## Done
- docs/migration.md, sections 1–4 drafted: Overview, Preparation, Breaking changes, Data migration. These edits are **uncommitted** and exist only in the working tree.
- docs/migration.md, section 3 (Breaking changes): the table was cross-checked against the v2.3 changelog, commit range `e5f0000..e7fff00`.

## In flight
- docs/migration.md, section 5 (Rollback): half-drafted. The prose is partial.
  - Its rollback-command code sample is **known-stale**. It still uses the v2.2 flag `--rollback-window`, which was renamed `--rollback-window-size` in v2.3.
  - The sample has not been fixed or re-verified.
  - Exact line numbers were not recorded. Locate the sample with the grep in Next steps.

## Next steps
1. Find the stale flag: `grep -n -- '--rollback-window' docs/migration.md`. Every match that lacks `-size` is a v2.2 flag. Change it to `--rollback-window-size`.
2. Confirm the rename against the changelog range: `git log e5f0000..e7fff00 -S'rollback-window-size' --oneline`.
3. Run the corrected rollback command against a v2.3 install, exactly as written in the doc, and confirm it works. The session state does not name the CLI binary. Read it from the sample itself.
4. Finish the section 5 (Rollback) prose.
5. Draft section 6 (FAQ). It has not been started.
6. Run every code sample in sections 1–5 verbatim. None of them has been run yet, so sections 1–4 are unverified too.
7. Run the doc build for the first time: `mkdocs build --strict`. Fix any warnings or errors.

## Verify
- `grep -n -- '--rollback-window\b' docs/migration.md | grep -v rollback-window-size` returns nothing.
- Each code sample in docs/migration.md runs verbatim against v2.3 without errors.
- `mkdocs build --strict` exits 0.
- docs/migration.md has exactly six top-level sections in the locked order: Overview, Preparation, Breaking changes, Data migration, Rollback, FAQ.

## Do not redo
- Do not re-cross-check the Breaking changes table against `e5f0000..e7fff00`. That check is done.
- Do not reopen the table of contents (TOC). The user locked the six sections.
- Do not rewrite sections 1–4. They are drafted. They only need their code samples executed (step 6).
- Do not run `git checkout`, `git stash`, or `git restore` on docs/migration.md. Sections 1–4 exist only as uncommitted working-tree edits.

## Context
- The user locked the TOC at six sections: Overview, Preparation, Breaking changes, Data migration, Rollback, FAQ.
- Preferences the user stated mid-session:
  - Use less jargon.
  - Keep the tables.
  - Code samples must run verbatim, so no placeholders that fail when pasted.
- Source of truth for v2.3 changes is the changelog, commit range `e5f0000..e7fff00`.
- Known v2.2 → v2.3 flag rename: `--rollback-window` → `--rollback-window-size`.
- Verification status: no code sample has been executed, and `mkdocs` has never been run on this doc.
--- end handoff.md ---
