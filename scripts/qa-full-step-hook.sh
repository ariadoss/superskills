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
# One jq read for every field the hook needs (each field() call was a spawn).
IFS=$'\t' read -r tool_name skill transcript agent session < <(
  printf '%s' "$input" | jq -r '[.tool_name, .tool_input.skill, .transcript_path, .agent_id, .session_id] | map(. // "") | @tsv' 2>/dev/null
)

[ "$tool_name" = "Skill" ] || exit 0
step="$(qfs_step_for_skill "$skill")"
[ -n "$step" ] || exit 0

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

# The once-per-agent marker is O(1); check it before the transcript scan so
# repeat calls of the same step exit on a stat, not a full jq pass.
state="${QA_FULL_STEP_STATE:-${TMPDIR:-/tmp}/superskills-qa-full-steps}"
marker="$(qfs_seen_marker "$state" "$session" "$agent" "$step")"
[ -e "$marker" ] && exit 0
qfs_step_read "$own" "$step" && exit 0

out="$(jq -n --arg step "$step" --rawfile body "$steps/$step" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    additionalContext: ("/qa-full step file steps/" + $step + ", supplied by the hook before this sub-skill runs. Follow it in full for this step (commit format, ledger evidence, fix and verify rules). You do not need to read it again.\n\n" + $body)
  }
}' 2>/dev/null)" || exit 0
# Mark delivered only after the JSON was built: a failed build must not
# permanently suppress the step for this agent.
marker_dir="$(dirname "$marker")"
mkdir -p "$marker_dir" 2>/dev/null
chmod 700 "$marker_dir" 2>/dev/null
[ -L "$marker" ] && exit 0 # never write through a pre-planted symlink
( set -C; : >"$marker" ) 2>/dev/null
printf '%s\n' "$out"
exit 0
