#!/usr/bin/env bash
# qa-full-step-hook.sh — Claude Code PreToolUse hook (matcher: Skill) for /qa-full.
#
# When an agent running /qa-full is about to invoke a sub-skill that belongs to
# a step (/review -> Step 3, /db-optimize -> Step 5, ...), this hook puts that
# step's file in the agent's context as additionalContext, once per agent. The
# harness supplies the text instead of asking the model to read it; the model
# skipped that read most of the time. Every other call exits 0 with no output.
#
# Fails open: no jq, no transcript, no step file, anything unexpected. It never
# blocks a tool call. Plugin installs get it from hooks/hooks.json; for ./setup
# installs scripts/install-qa-full-ledger-hook.sh prints the settings entry.
# Tested in tests/qa-full-step-hook.bats.

set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/qa-full-step-lib.sh
. "$here/lib/qa-full-step-lib.sh"

input="$(cat)"
field() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

[ "$(field .tool_name)" = "Skill" ] || exit 0
step="$(qfs_step_for_skill "$(field .tool_input.skill)")"
[ -n "$step" ] || exit 0

transcript="$(field .transcript_path)"
agent="$(field .agent_id)"
session="$(field .session_id)"
[ -f "$transcript" ] || exit 0
own="$(qfs_agent_transcript "$transcript" "$agent")"

is_sub=0
[ -n "$agent" ] && is_sub=1
dir="$(qfs_skill_dir "$own" "$is_sub")"
[ -n "$dir" ] || exit 0

# Where the step files live: the folder this agent loaded, else this install.
steps="$dir/steps"
[ -f "$steps/$step" ] || steps="$here/../skills/qa-full/steps"
[ -f "$steps/$step" ] || exit 0

qfs_step_read "$own" "$step" && exit 0
state="${QA_FULL_STEP_STATE:-${TMPDIR:-/tmp}/superskills-qa-full-steps}"
marker="$(qfs_seen_marker "$state" "$session" "$agent" "$step")"
[ -e "$marker" ] && exit 0
mkdir -p "$(dirname "$marker")" 2>/dev/null && : >"$marker" 2>/dev/null

jq -n --arg step "$step" --rawfile body "$steps/$step" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: ("/qa-full step file steps/" + $step + ", supplied by the hook before this sub-skill runs. Follow it in full for this step (commit format, ledger evidence, fix and verify rules). You do not need to read it again.\n\n" + $body)
  }
}'
exit 0
