---
name: handoff
version: 1.0.0
description: |
  Write a per-session handoff-<session-id>.md for the agent session that resumes this work —
  in-progress state, exact next steps, and this session's reference (path +
  resume command), so a fresh session can continue cheaply instead of
  reconstructing. Use only when manually invoked or when the automatic hook
  reports that the context window is at 90%, the 5-hour usage window at 90%,
  or the weekly window at 95%. Composes with /quota-resilience, which owns quota hard
  stops. Works across Claude Code, Codex, OpenCode, and minimal harnesses.
argument-hint: '[note to append, optional]'
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
---

# /handoff

Write `handoff-<session-id>.md` at the repo root (the exact name is the
`handoff file:` line Step 1 prints): the bridge a successor session reads
first. One file per session, so parallel sessions never overwrite each
other; re-running `/handoff` in the same session updates that session's own
file. It is uncommitted by design: the durable record is git itself; the handoff
is the ephemeral state git cannot hold (what is half-done, what to verify
first, how to resume THIS session). In superskills checkouts the file is
gitignored; elsewhere it stays untracked (and superskills' own
export ships an ignore rule for standalone users).

## When

- Manually, whenever the user invokes `/handoff`.
- Automatically: the plugin's `UserPromptSubmit` hook nudges the agent to
  run this skill, once per trigger, when any of these is reached:
  this session's context window at `HANDOFF_USAGE_THRESHOLD` (default 90%),
  the account's 5-hour window at `HANDOFF_FIVE_HOUR_THRESHOLD` (default 90%),
  or the weekly window at `HANDOFF_WEEKLY_THRESHOLD` (default 95%). It reads
  the numbers the superskills statusline publishes (`./setup --statusline`);
  without that statusline only manual invocation works. It never fires
  before the session's first assistant reply. The nudge supplies
  `transcript_path` and `session_id`. Use them.

## Step 1 — the session reference

Run this skill's session-ref script. Resolve its path relative to THIS
skill's directory (wherever the host loaded it from: plugin installs and
the standalone repo both keep it at `scripts/session-ref.sh` directly under
the skill):

```bash
bash "$(dirname <this-SKILL.md-path>)/scripts/session-ref.sh"
```

If the nudge or caller provided a session id and transcript path, set them
first so they win over discovery:

```bash
HANDOFF_SESSION_ID="<session_id>" HANDOFF_SESSION_FILE="<transcript_path>" \
  bash "$(dirname <this-SKILL.md-path>)/scripts/session-ref.sh"
```

The script prints the `handoff file:` name to write, the session file (absolute path), the verified resume
command for the harness it detected (Claude Code / Codex / OpenCode), or the
honest unknown-harness fallback. If it prints a `caution:` line, verify the
transcript really is this session's before trusting it (check its mtime).

## Step 2 — write the note (the eval-winning content model)

This shape won the 2026-10-06 bake-off (`evals/reports/2026-10-06-handoff-bakeoff.md`):
weakly preferred by both the calibrated judge (4.958/5) and the behavioral
recall layer, never worse than the runner-up beyond noise. Edit deliberately.

```markdown
# Handoff — <task one-liner> @ <date>
written by session <session-id-or-unknown> @ <iso timestamp>

## Session
<the session-ref script's output, verbatim>

## Goal
<one line: the task's definition of done>

## Done
- <bullets, each with its commit hash or file:line>

## In flight
- <file:line, what exists, what is missing, what is unverified>

## Next steps
1. <the single next action, as an exact command>
2. <ordered, each executable without re-deriving context — exact commands>

## Verify
<the command(s) that prove the goal is met>

## Do not redo
- <finished work the successor must not repeat>
- <known-dead approaches already tried>

## Context
- <decisions made this session>
- <user preferences stated this session>
- <pointers: plan files, ledgers, reports>
```

The reader is a fresh agent with NO memory of this session: every line must
be self-contained (no "as above", no pronouns without antecedents), must
build on work already done, and must not duplicate finished work. Target
40-80 lines; a note longer than the session state it summarizes has failed.

Facts only. Commit hashes, file:line anchors, exact commands. No padding,
no speculation. If `$ARGUMENTS` carries a user note, fold it into Context.

## Step 3 — composition

- On the quota hard stop, `/quota-resilience` folds this file into
  `QUOTA-RESUME.md` and deletes it: one bridge, not two. Do not leave both.
- Parallel sessions each own a distinct `handoff-<id>.md`; the header
  still records which session wrote it. A successor with no pointer reads
  the newest `handoff-*.md` in the repo root, and checks the header's session
  against the work it finds.
- In a minimal harness with no session persistence, this file is the ONLY
  bridge: say so in the note when session-ref prints the unknown-harness
  fallback, and let the successor rebuild from the note plus git.
