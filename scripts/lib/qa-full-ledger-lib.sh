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
# Always succeeds: a malformed transcript (a subagent killed mid-write) yields
# only the records before its bad line. Returning the last jq's status instead
# made every caller's pipeline fail under the hook's pipefail whenever the LAST
# transcript was truncated, so the hook silently skipped the whole check.
_qfl_tool_uses() {
  local f
  for f in "$@"; do
    [ -f "$f" ] || continue
    jq -c 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use")' "$f" 2>/dev/null
  done
  return 0
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
      if (names != "") { print names; next }
      # A RAN row with no /skill name used to be dropped here, so a reformatted
      # cell ("Review Step 3") claiming RAN-CLEAN escaped the check entirely.
      # Only the rows the qa-full template makes skill-less by design are exempt.
      label = $2; gsub(/^[ \t]+|[ \t]+$/, "", label)
      # Exact template labels only: a prefix match let "Final pass review step 3"
      # claim RAN-CLEAN unchecked.
      if (tolower(label) ~ /^(tests & build|final pass)( \(step (2|10)\))?$/) next
      # Emit ONE token outside the skill-name alphabet ([a-z0-9-]), so it can
      # never word-split into, or match, an invoked skill such as "review". It
      # names the row by LINE, never by its text: the hook relays this to the
      # agent as feedback, and report text may come from a repository the
      # session did not write (/cso 575717a8, prompt injection).
      print "unnamed:L" NR
    }' "$1"
}

# qfl_format_missing — reads qfl_missing output on stdin, prints one bullet per
# row for the hook's message: "/a or /b" for a row naming skills, and the line
# number for an unnamed row, so it never reads like a slash command to invoke.
qfl_format_missing() {
  local row
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    case "$row" in
      unnamed:L*) printf '  - the row on line %s claims a check ran but names no /skill\n' "${row#unnamed:L}" ;;
      *) printf '  - /%s\n' "${row// / or /}" ;;
    esac
  done
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

# _qfl_mtime <file> — modification time in epoch seconds, or nothing.
# GNU stat reads BSD's `-f %m FILE` as --file-system and prints multi-line
# filesystem info before failing, so each attempt is captured separately and
# printed only on its own success; one can never leak into the other's output.
_qfl_mtime() {
  local m
  m="$(stat -c %Y "$1" 2>/dev/null)" && [ -n "$m" ] && { printf '%s\n' "$m"; return 0; }
  m="$(stat -f %m "$1" 2>/dev/null)" && [ -n "$m" ] && { printf '%s\n' "$m"; return 0; }
  return 1
}

# qfl_session_start <transcript...> — the earliest record timestamp across the
# transcripts, as epoch seconds; nothing when no record carries one. jq's
# fromdateiso8601 rejects fractional seconds, so they are stripped first.
qfl_session_start() {
  local f
  # One jq PER transcript, deliberately. A single jq over all of them aborts the
  # whole stream at the first malformed line (a session killed mid-write), which
  # blanked this floor and silently disabled the stale-report check. Per file, a
  # truncated line costs only that file's later records. This runs once, at
  # session stop, so the extra forks are not on any hot path.
  for f in "$@"; do
    [ -f "$f" ] || continue
    jq -r 'select(type=="object") | .timestamp // empty' "$f" 2>/dev/null
  done | jq -Rr 'sub("\\.[0-9]+Z$"; "Z") | try fromdateiso8601 catch empty' 2>/dev/null \
       | LC_ALL=C sort -n | head -1
}

# qfl_latest_report <project-dir> [min-epoch] — newest qa-full-reports/*.md, or
# nothing. With min-epoch, a report last modified before it is not a candidate:
# the session cannot have written it.
qfl_latest_report() {
  local dir="$1" min="${2:-}" f m
  # Read line-wise: `for f in $(ls ...)` would word-split the project path itself.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ -n "$min" ]; then
      m="$(_qfl_mtime "$f")"
      # Unreadable mtime (file vanished mid-scan) is not evidence of freshness.
      [ -n "$m" ] || continue
      [ "$m" -lt "$min" ] && continue
    fi
    printf '%s\n' "$f"
    return 0
  done < <(ls -t "$dir"/qa-full-reports/*.md 2>/dev/null)
}

# qfl_written_report <transcript...> — the last qa-full report the session
# wrote with Write or Edit, or nothing.
qfl_written_report() {
  _qfl_tool_uses "$@" | jq -r 'select(.name=="Write" or .name=="Edit") | .input.file_path // empty' \
    | grep '/qa-full-reports/[^/]*\.md$' | tail -1
}

# qfl_report_path <cwd> <transcript...> — the last report the session wrote
# (qa-full may run against a repo other than the session cwd), else the newest
# report under the cwd that is no older than the session.
#
# The fallback exists because a report written by a Bash heredoc is invisible to
# qfl_written_report. It used to accept ANY report under the cwd, so a session
# that ran /qa-full against another repo (an eval fixture, a sibling project)
# was sent back to justify a days-old ledger it never wrote. A report is now
# rejected only when the transcript's own timestamps prove it predates the
# session; a transcript without timestamps keeps the old behaviour.
qfl_report_path() {
  local cwd="$1"; shift
  local written
  written="$(qfl_written_report "$@")"
  if [ -n "$written" ]; then printf '%s\n' "$written"; return 0; fi
  qfl_latest_report "$cwd" "$(qfl_session_start "$@")"
}
