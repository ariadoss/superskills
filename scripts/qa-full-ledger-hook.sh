#!/usr/bin/env bash
# qa-full-ledger-hook.sh — Claude Code Stop / SubagentStop hook for /qa-full.
#
# When the stopping session ran /qa-full, every ledger row marked RAN-CLEAN,
# FIXED or UNFIXED must have a matching Skill tool call in the transcript (or
# in the session's subagent transcripts). If one is missing, or qa-full wrote
# no report, the hook exits 2 and its stderr tells Claude which checks to
# invoke or re-mark SKIPPED(reason). Every other session exits 0 at once.
#
# Fails open: no jq, no transcript, or a second consecutive block
# (stop_hook_active) all exit 0, so the hook can never wedge a session.
# Install: scripts/install-qa-full-ledger-hook.sh prints the settings snippet;
# plugin installs get it from hooks/hooks.json. Tested in tests/qa-full-ledger-lib.bats.

set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
# shellcheck source=scripts/lib/qa-full-ledger-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/qa-full-ledger-lib.sh"

input="$(cat)"
field() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

[ "$(field .stop_hook_active)" = "true" ] && exit 0
transcript="$(field .agent_transcript_path)"
[ -n "$transcript" ] || transcript="$(field .transcript_path)"
[ -f "$transcript" ] || exit 0
cwd="$(field .cwd)"

transcripts=("$transcript")
for sub in "${transcript%.jsonl}"/subagents/*.jsonl; do
  [ -f "$sub" ] && transcripts+=("$sub")
done

# Cheap text scan first so ordinary sessions never pay for the jq parse.
grep -q 'qa-full' "${transcripts[@]}" 2>/dev/null || exit 0
if qfl_invoked_qafull "${transcripts[@]}"; then
  report="$(qfl_report_path "${cwd:-.}" "${transcripts[@]}")"
elif qfl_read_qafull "${transcripts[@]}"; then
  # Read the file but wrote no report: someone editing qa-full, not running it.
  report="$(qfl_written_report "${transcripts[@]}")"
  [ -n "$report" ] || exit 0
else
  exit 0
fi
if [ -z "$report" ] || [ ! -f "$report" ]; then
  echo "/qa-full ran but wrote no report under qa-full-reports/. Finish Step 10: write the report with its accounting ledger." >&2
  exit 2
fi

missing="$(qfl_missing "$report" "${transcripts[@]}")"
[ -z "$missing" ] && exit 0

{
  echo "The /qa-full ledger in $report marks these checks as run, but this session never invoked them with the Skill tool:"
  printf '%s\n' "$missing" | sed 's#^#  - /#; s# # or /#g'
  echo "Invoke each one with the Skill tool and fold its result into the ledger, or change the row to SKIPPED(reason) if it cannot run here."
} >&2
exit 2
