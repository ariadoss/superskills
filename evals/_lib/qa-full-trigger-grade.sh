#!/usr/bin/env bash
# qa-full-trigger-grade.sh <fixture-dir> <py|hard|docs>
# Prints: case=<c> db=<value|missing> ui=<value|missing> pass=<0|1>
set -u
dir="$1"; case_="$2"
f="$dir/decision.txt"
db="$(sed -n 's/^db: *//p' "$f" 2>/dev/null | head -1 | tr -d '[:space:]')"
ui="$(sed -n 's/^ui: *//p' "$f" 2>/dev/null | head -1 | tr -d '[:space:]')"
want="TRIGGERED"; [ "$case_" = docs ] && want="NOT-TRIGGERED"
pass=0; [ "$db" = "$want" ] && [ "$ui" = "$want" ] && pass=1
printf 'case=%s db=%s ui=%s pass=%s\n' "$case_" "${db:-missing}" "${ui:-missing}" "$pass"
