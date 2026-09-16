#!/usr/bin/env bash
# eval-traces.sh — archive and summarise the transcripts of a plugin-eval run.
#
# `claude plugin eval --keep-temp --json <file>` leaves each run's trace in a
# /tmp dir that does not survive reboots. This copies every trace next to the
# results (<out>/<case>/<arm>-<n>.jsonl) and prints one summary per run — the
# raw material for the open-coding pass described in evals/RUBRIC.md.
#
# Usage: scripts/eval-traces.sh <run.json> <out-dir>
set -e
RESULT="$1"; OUT="$2"
[ -f "$RESULT" ] && [ -n "$OUT" ] || { echo "usage: $0 <run.json> <out-dir>" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 127; }

jq -r '.cases[] | .name as $c | .arms | to_entries[] | .key as $arm | .value | to_entries[] |
  [$c, $arm, (.key + 1), (.value.score // "null"), (.value.error // ""), (.value.tracePath // ""),
   ([.value.graders[]? | select(.passed == false) | .name + (if .scored == false then " (indicator)" else "" end) + ": " + ((.explanation // "") | gsub("\n"; " ") | .[0:160])] | join(" | "))]
  | map(tostring) | join("\u001f")' "$RESULT" |
# Unit separator, not tab: tab is IFS whitespace, so empty fields would collapse.
while IFS=$'\x1f' read -r case arm n score err trace failed; do
  dest="$OUT/$case/$arm-$n.jsonl"
  mkdir -p "$OUT/$case"
  echo "════ $case / $arm-$n / score $score"
  [ -n "$err" ] && echo "  ERROR: $err"
  if [ -f "$trace" ]; then
    cp "$trace" "$dest"
    jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") |
      "  - " + .name + " " + ((.input.command // .input.skill // .input.file_path // .input.pattern // "") | gsub("\n"; " ") | .[0:200])' "$dest"
    echo "  final:"
    jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' "$dest" | tail -n 25 | sed 's/^/    /'
  else
    echo "  (trace missing: $trace)"
  fi
  [ -n "$failed" ] && echo "  FAILED $failed"
  echo
done
