---
max_turns: 4
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Write, Skill]
tags: [handoff, resume, A]
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
# Handoff: v2.3 migration guide (`docs/migration.md`)

## Task
Rewrite `docs/migration.md` as the v2.3 migration guide. The user has **locked** the table of contents at six sections. Do not add, drop, rename or reorder sections without asking them:
1. Overview
2. Preparation
3. Breaking changes
4. Data migration
5. Rollback
6. FAQ

## Current state
| Section | Status |
|---|---|
| 1. Overview | Drafted (uncommitted, in working file) |
| 2. Preparation | Drafted (uncommitted) |
| 3. Breaking changes | Drafted (uncommitted). Table cross-checked against the v2.3 changelog, commit range `e5f0000..e7fff00` |
| 4. Data migration | Drafted (uncommitted) |
| 5. Rollback | **Half-drafted, in flight** |
| 6. FAQ | Not started |

All work so far is **uncommitted**. Look at the working tree before editing, and don't discard or overwrite it.

## Known problem: stale code sample in section 5
- The rollback-command code sample in section 5 is **known stale**. It uses v2.2 flags.
- Specifically, v2.3 renamed `--rollback-window` to `--rollback-window-size`.
- No one has re-verified it against v2.3. There may be other stale flags beyond the rename, so check the whole command against the v2.3 CLI or changelog, and fix more than the one flag if needed.

## Verification status
- **None of the code samples (sections 1 to 5) have been run.** The only verified thing is the Breaking changes table, which was checked against the changelog.
- The doc build (`mkdocs`) has **never been run**.

## User preferences (stated mid-session)
- **Less jargon.** Use plain language and define any term you have to use.
- **Keep the tables.** Don't turn them into prose.
- **Code samples must run verbatim.** No placeholders that break copy-paste, and no unverified flags.

## Next steps (in order)
1. Read the current working file to pick up the drafted text for sections 1 to 4 and the partial section 5.
2. Finish section 5 (Rollback). Fix the stale command: replace `--rollback-window` with `--rollback-window-size` and check every other flag against v2.3.
3. Draft section 6 (FAQ) in the same plain-language style.
4. Run every code sample in the doc (sections 1 to 6) against v2.3 and fix any that fail. Until that's done, don't call any sample "runnable."
5. Run the mkdocs build and fix any warnings or errors (broken links, table rendering).
6. Do a final jargon pass to match the user's preference.
7. Ask the user before committing.

## Session
- session file: `/Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl`
- resume: `claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"`
- fallback: `claude -c -p "<prompt>"`
--- end handoff.md ---
