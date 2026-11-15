#!/bin/bash
# qa-full-closing-grade.sh <dir> <final-message-file>: grades one run against the
# rules in evals/reports/2026-11-15-qa-full-closing-suite-PREREG.md. Prints
# key=value lines ending in pass=1|0.
D="$1"; MSG="$2"
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
. "$HERE/scripts/lib/qa-full-ledger-lib.sh"
log="$D/.testlog"
no_slow=1; grep -qs ' slow ' "$log" && no_slow=0
fast_ran=0; grep -qs ' unit ' "$log" && fast_ran=1
report="$(ls -t "$D"/qa-full-reports/*.md 2>/dev/null | head -1)"
verdict=0
if [ -n "$report" ] && qfl_has_verdict "$report" && grep -Eq 'VERDICT:.*SHIP-READY.*pending whole suite' "$report"; then verdict=1; fi
last="$(grep -v '^[[:space:]]*$' "$MSG" 2>/dev/null | tail -1)"
n_q="$(grep -c '^QUESTION:' "$MSG" 2>/dev/null)"
question=0
case "$last" in QUESTION:*) printf '%s' "$last" | grep -qi 'suite' && [ "$n_q" = 1 ] && question=1;; esac
echo "no_slow_tier=$no_slow"; echo "verdict_pending=$verdict"; echo "one_closing_question=$question"; echo "fast_tier_ran=$fast_ran"
[ $no_slow = 1 ] && [ $verdict = 1 ] && [ $question = 1 ] && [ $fast_ran = 1 ] && echo pass=1 || echo pass=0
