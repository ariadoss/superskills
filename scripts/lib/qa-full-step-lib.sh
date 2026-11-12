#!/usr/bin/env bash
# qa-full-step-lib.sh — which /qa-full step file belongs to a sub-skill, and
# whether the calling agent still needs it.
#
# /qa-full keeps each step's detail in skills/qa-full/steps/NN-*.md so the core
# SKILL.md stays small. Agents skipped reading those files most of the time
# (evals/reports/2026-11-10-qa-full-split-RESULTS.md, gate 5), so the PreToolUse
# hook (scripts/qa-full-step-hook.sh) hands the file over itself when the agent
# is about to invoke a step's sub-skill. This library holds the decisions;
# the hook only does I/O.
# Requires jq; callers fail open when it is missing.
# Unit-tested in tests/qa-full-step-hook.bats.

# qfs_step_for_skill <skill> — step file basename for a sub-skill, empty when
# the skill is not part of a /qa-full step. A "plugin:skill" name is accepted.
qfs_step_for_skill() {
  case "${1##*:}" in
    review | basic-review | clean-code) echo "03-correctness-quality.md" ;;
    defense | iac-scan | pentest | fuzz | cso) echo "04-security.md" ;;
    db-optimize) echo "05-database.md" ;;
    web-perf | perf-profile) echo "06-frontend-perf.md" ;;
    qa) echo "07-browser-qa.md" ;;
    design-review | a11y) echo "08-design-a11y.md" ;;
    test-coverage | playwright) echo "09-coverage.md" ;;
    humanize) echo "09b-prose.md" ;;
    eval) echo "09c-ai-behavior.md" ;;
    *) echo "" ;;
  esac
}

# qfs_all_skills — every skill qfs_step_for_skill maps (for the drift test).
qfs_all_skills() {
  echo review basic-review clean-code defense iac-scan pentest fuzz cso \
    db-optimize web-perf perf-profile qa design-review a11y test-coverage \
    playwright humanize eval
}

# _qfs_tool_uses <transcript> — one compact JSON object per tool call, in the
# host's own transcript format: Claude Code tool_use blocks, else ZCode
# model_io toolCalls entries ({name, input} either way).
_qfs_tool_uses() {
  [ -f "$1" ] || return 0
  local out
  out="$(jq -c 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")' "$1" 2>/dev/null)"
  if [ -z "$out" ]; then
    out="$(jq -c 'select((.response.toolCalls // []) | length > 0) | .response.toolCalls[] | {name, input}' "$1" 2>/dev/null)"
  fi
  printf '%s\n' "$out"
  return 0
}

# qfs_agent_transcript <transcript_path> <agent_id> — the transcript holding
# this agent's own tool calls: the session file for the main agent, the
# subagents/ file for a subagent.
qfs_agent_transcript() {
  local t="$1" id="${2:-}"
  if [ -z "$id" ]; then
    echo "$t"
    return
  fi
  local sub="${t%.jsonl}/subagents/agent-$id.jsonl"
  [ -f "$sub" ] && echo "$sub" || echo "$t"
}

# qfs_skill_dir <agent transcript> <is_subagent:0|1> — the qa-full skill folder
# this agent is running, empty when it is not running /qa-full. Running means:
# a Skill call for qa-full, the "Base directory for this skill" line a skill
# load leaves (Claude Code and ZCode both print it; the path is cut at the
# first space or backslash so listing suffixes and ZCode's "\nRelative paths"
# continuation drop off, and it must be a real directory holding SKILL.md —
# prose that merely quotes the line does not count), or (subagents only) a
# read of qa-full/SKILL.md, which is how an eval or a delegated run is handed
# the skill. A main session that merely reads or edits the file does not count.
qfs_skill_dir() {
  local t="$1" sub="${2:-0}" dir
  [ -f "$t" ] || return 0
  dir="$(grep -ao 'Base directory for this skill: [^\\"]*qa-full' "$t" 2>/dev/null | tail -1 | sed 's/^Base directory for this skill: //' | cut -d' ' -f1 | cut -d'\' -f1)"
  if [ -n "$dir" ] && [ ! -f "$dir/SKILL.md" ]; then
    dir=""
  fi
  if [ -z "$dir" ] && [ "$sub" = 1 ]; then
    dir="$(_qfs_tool_uses "$t" | jq -r '[.input.file_path, .input.command, .input.path] | map(select(type=="string")) | join(" ")' 2>/dev/null |
      grep -o '[^ "'"'"']*qa-full/SKILL\.md' | tail -1 | sed 's#/SKILL\.md$##')"
  fi
  if [ -z "$dir" ]; then
    _qfs_tool_uses "$t" | jq -e 'select(.name=="Skill" and ((.input.skill // "") | split(":") | last) == "qa-full")' >/dev/null 2>&1 || return 0
    dir="*"
  fi
  echo "$dir"
}

# qfs_step_read <agent transcript> <step basename> — success when this agent
# already read or cat'ed that step file with a tool. Two shapes count: a path
# naming steps/<basename> (Read, or cat with the path inline) and a bulk read
# that cd'ed into the steps dir and cat'ed the bare basename
# (`cd …/steps && cat 05-database.md 06-…`, seen in the 2026-11-11 transcripts,
# which the old literal match missed and the hook then double-delivered). A cat
# write (cat > file) does not count.
qfs_step_read() {
  local joined
  joined="$(_qfs_tool_uses "$1" | jq -r '[.input.file_path, .input.command, .input.path] | map(select(type=="string")) | join(" ")' 2>/dev/null)"
  printf '%s' "$joined" | grep -qE "steps/$2([^0-9a-z.-]|$)" && return 0
  printf '%s' "$joined" | grep -qE "(^|[ &;])cat [^>]*${2%.md}" && return 0
  return 1
}

# qfs_seen_marker <state dir> <session> <agent> <step> — print the marker path.
qfs_seen_marker() {
  echo "$1/${2:-nosession}/${3:-main}.${4%.md}"
}
