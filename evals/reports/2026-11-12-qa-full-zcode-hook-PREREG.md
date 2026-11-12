# Pre-registration: the /qa-full step-file hook in ZCode (2026-11-12)

Written before any live run. Thresholds do not change after results come in.
Follows the Claude Code step-hook eval (`2026-11-11-qa-full-step-hook-{PREREG,RESULTS}.md`),
which passed all gates there (18/18 heavy, 12/12 light delivery).

## Question

Does the same PreToolUse hook (`scripts/qa-full-step-hook.sh`) deliver /qa-full
step files in ZCode, given ZCode's own transcript format and hook plumbing?

## What is already verified without a run (2026-11-12)

- ZCode hooks support PreToolUse with `hookSpecificOutput.additionalContext`
  injection, Claude-style snake_case stdin fields (`tool_name`, `tool_input`,
  `transcript_path`, `session_id`), and a `Skill` tool matcher; hooks are off
  by default (`hooks.enabled: true` in `~/.zcode/cli/config.json`) and plugin
  `hooks/hooks.json` is auto-discovered only for plugin installs — this machine
  installs skills into `~/.zcode/skills/`, so the hook needs user-level
  registration.
- ZCode transcripts live at `~/.zcode/cli/rollout/model-io-sess_*.jsonl` with
  tool calls in `.response.toolCalls[] = {id, name, input}` and the same
  `input` field names Claude uses (`command`, `file_path`). The skill-load
  footer `Base directory for this skill: <dir>` is printed with the same
  wording as Claude Code.
- `scripts/lib/qa-full-step-lib.sh` now reads both transcript formats
  (`_qfs_tool_uses` dual-format; `qfs_skill_dir` cuts the dir at the first
  space/backslash and requires it to exist with a SKILL.md, so prose that
  quotes the footer cannot start a run). 19 bats tests pass
  (`tests/qa-full-step-hook.bats`), including four new ones: ZCode footer
  injection, ZCode Read-counts-as-read, prose-quote guard, and Claude
  listing-suffix trimming. Verified against a real ZCode session transcript
  (no false positive despite dozens of conversational "qa-full" mentions) and
  the real Claude eval transcript (arm dir still resolves).

## Live-check arm (free, no model spend beyond the session itself)

A fresh ZCode session (config is snapshotted per session, so enabling hooks
needs a new one) with the split installed (`./setup`) and the hook registered
user-level:

```json
"hooks": {
  "enabled": true,
  "events": {
    "PreToolUse": [
      {"matcher": "Skill", "hooks": [
        {"type": "process", "command": "/bin/bash",
         "args": ["/Users/danilosapad/Sites/superskills/scripts/qa-full-step-hook.sh"]}
      ]}
    ]
  }
}
```

The registration edits `~/.zcode/cli/config.json` — the user approves that
file change before it happens (hooks execute local code on every matched
call). Smoke first: one session, one /qa-full run on a heavy fixture.

## Measures

Same as the Claude eval: a step is **delivered** when the transcript shows the
step file's text (header `/qa-full step file steps/NN`) before that step's
first sub-skill output; **pairs** are the steps whose sub-skill ran; correct /
unbacked / secret-absent per `evals/_lib/qa-full-grade.sh`.

## Gates

1. **Smoke (n=1):** at least one injection reaches the model in the run; zero
   injections in a control session that invokes a mapped sub-skill without
   running /qa-full; tool calls proceed when the hook is absent or errors
   (fail-open).
2. **Delivery:** at least 90% of heavy pairs across n=3 runs.
3. **No loss of effect:** heavy correct at least 2 of 3; light 3 of 3.
4. **No double work, transcript-checked** (the 2026-11-12 token audit found
   the Claude eval missed bulk-cat double delivery by unit-testing only): no
   step file both read by the agent and injected by the hook in the same run.

## Limits

n=3 pilot. The graders do not see real compaction. ZCode's exact hook stdin
field names and the file `transcript_path` names are documented but unobserved
on this machine until the smoke run; if they differ, the hook fails open (no
injection) and the smoke documents the difference instead of forcing a pass.
