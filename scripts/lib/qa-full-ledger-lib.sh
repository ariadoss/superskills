#!/usr/bin/env bash
# qa-full-ledger-lib.sh — checks a /qa-full accounting ledger against what the
# session actually invoked.
#
# /qa-full's ledger marks each check RAN-CLEAN, FIXED(n), UNFIXED, SKIPPED(...),
# NOT-TRIGGERED or MANDATORY-FAIL. A row that says the check ran is only true if
# the session loaded that sub-skill with the Skill tool; reconstructing a
# check by hand is not running it. These functions read Claude Code JSONL
# transcripts and the report markdown and list the rows with no matching call.
#
# Used by scripts/qa-full-ledger-hook.sh (Stop/SubagentStop hook) and by the
# qa-full eval grader. Requires jq; callers fail open when it is missing.
# Unit-tested in tests/qa-full-ledger-lib.bats.

# _qfl_tool_uses <transcript...> — one compact JSON object per tool_use block.
_qfl_tool_uses() {
  local f
  for f in "$@"; do
    [ -f "$f" ] || continue
    jq -c 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")' "$f" 2>/dev/null
  done
}

# qfl_invoked_skills <transcript...> — skill names loaded via the Skill tool,
# plugin prefix ("superskills:") stripped, sorted and unique.
qfl_invoked_skills() {
  _qfl_tool_uses "$@" | jq -r 'select(.name=="Skill") | .input.skill // empty' | sed 's/^.*://' | LC_ALL=C sort -u
}

# qfl_invoked_qafull <transcript...> — exit 0 when the session invoked /qa-full
# through the Skill tool or as a typed slash command.
qfl_invoked_qafull() {
  qfl_invoked_skills "$@" | grep -qx 'qa-full' && return 0
  local f
  for f in "$@"; do
    [ -f "$f" ] || continue
    jq -r 'select(.type=="user") | .message.content | if type=="string" then . else (map(.text? // "") | join(" ")) end' "$f" 2>/dev/null \
      | grep -q '<command-name>/qa-full</command-name>' && return 0
  done
  return 1
}

# qfl_read_qafull <transcript...> — exit 0 when the session read qa-full's
# SKILL.md directly (either following it by hand or just editing it).
qfl_read_qafull() {
  _qfl_tool_uses "$@" | jq -r 'select(.name=="Read") | .input.file_path // empty' \
    | grep -q '/qa-full/SKILL\.md$'
}

# qfl_ran_qafull <transcript...> — invoked it, or read its SKILL.md.
qfl_ran_qafull() {
  qfl_invoked_qafull "$@" || qfl_read_qafull "$@"
}

# qfl_ran_rows <report.md> — for each ledger row whose status says the check
# ran (RAN-CLEAN, FIXED, UNFIXED), the /skill names in its first cell,
# space-separated. Rows that name no skill (Tests & build, Final pass) are skipped.
qfl_ran_rows() {
  awk -F'|' '
    NF >= 4 {
      status = $3; gsub(/^[ \t]+|[ \t]+$/, "", status)
      if (status !~ /^(RAN-CLEAN|FIXED|UNFIXED)/) next
      cell = $2; names = ""
      while (match(cell, /\/[a-z0-9][a-z0-9-]*/)) {
        names = names (names == "" ? "" : " ") substr(cell, RSTART + 1, RLENGTH - 1)
        cell = substr(cell, RSTART + RLENGTH)
      }
      if (names != "") print names
    }' "$1"
}

# qfl_missing <report.md> <transcript...> — ledger rows claimed as run where no
# named skill was invoked; prints each such row's names.
qfl_missing() {
  local report="$1"; shift
  local invoked row name hit
  invoked="$(qfl_invoked_skills "$@")"
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    hit=""
    for name in $row; do
      printf '%s\n' "$invoked" | grep -qx "$name" && { hit=1; break; }
    done
    [ -n "$hit" ] || printf '%s\n' "$row"
  done < <(qfl_ran_rows "$report")
}

# qfl_latest_report <project-dir> — newest qa-full-reports/*.md, or nothing.
qfl_latest_report() {
  local newest
  newest="$(ls -t "$1"/qa-full-reports/*.md 2>/dev/null | head -1)"
  [ -n "$newest" ] && printf '%s\n' "$newest"
}

# qfl_written_report <transcript...> — the last qa-full report the session
# wrote with Write or Edit, or nothing.
qfl_written_report() {
  _qfl_tool_uses "$@" | jq -r 'select(.name=="Write" or .name=="Edit") | .input.file_path // empty' \
    | grep '/qa-full-reports/[^/]*\.md$' | tail -1
}

# qfl_report_path <cwd> <transcript...> — the last report the session wrote
# (qa-full may run against a repo other than the session cwd), else the newest
# report under the cwd.
qfl_report_path() {
  local cwd="$1"; shift
  local written
  written="$(qfl_written_report "$@")"
  if [ -n "$written" ]; then printf '%s\n' "$written"; else qfl_latest_report "$cwd"; fi
}
