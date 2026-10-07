# handoff

A cross-harness `/handoff` skill for coding agents: writes a `handoff.md`
at the repo root — in-progress state, exact next steps, and this session's
reference (absolute session/transcript path plus the verified resume
command), so a fresh session can resume the work cheaply instead of
reconstructing it.

## Two trigger modes

- **Manual** — invoke `/handoff` any time the work is unfinished and the
  session may end (before compaction, before handing off, at day's end).
- **Automatic** — a `UserPromptSubmit` hook nudges the agent to run
  `/handoff` once per session (per rate-limit window) when account usage
  crosses 90% (`HANDOFF_USAGE_THRESHOLD` overrides). Standalone wiring:
  copy `hooks/handoff-trigger-hook.sh` somewhere stable, add to your
  Claude Code hooks config:

  ```json
  { "hooks": { "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "/path/to/handoff-trigger-hook.sh" } ] } ] } }
  ```

  The hook reads the rate-limit cache written by
  [superskills](https://github.com/ariadoss/superskills)' statusline
  (`~/.cache/claude-statusline/rate-limits.json`). Without that statusline
  there is no cache and only manual invocation works. Nothing breaks.

## Harness support

| Harness | Session reference | Resume |
|---|---|---|
| Claude Code | `~/.claude/projects/<munged-cwd>/<session-id>.jsonl` (exact-munge binding, 6h window) | `claude --resume <id> -p "<prompt>"` (fallback `claude -c`) |
| Codex | newest rollout under `~/.codex/sessions/YYYY/MM/DD/` (thread caution included) | `codex exec resume --last "<prompt>"` |
| OpenCode | no stable on-disk path published | `opencode run -c "<prompt>"` |
| Unknown / minimal | honest no-resume note | handoff.md is the only bridge |

## Install

Copy `SKILL.md` and `scripts/` into your agent's skills directory (e.g.
`~/.claude/skills/handoff/`), or install the
[superskills](https://github.com/ariadoss/superskills) plugin, which ships
and updates it.

## Provenance

Canonical source: [ariadoss/superskills](https://github.com/ariadoss/superskills)
(`skills/handoff/`); this repo is its standalone export; file issues there.
The note's content model won a pre-registered three-variant bake-off
(judge + behavioral resume evals); see superskills' `evals/reports/`.
