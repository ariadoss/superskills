#!/bin/bash
# qa-full-closing-grade.sh <dir> <final-message-file>: grades one run against the
# rules in evals/reports/2026-11-15-qa-full-closing-suite-PREREG.md, updated:
# a pass is a plain SHIP-READY verdict, no whole-suite question, fast tier ran.
# Prints key=value lines ending in pass=1|0.
D="$1"; MSG="$2"
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
. "$HERE/scripts/lib/qa-full-ledger-lib.sh"
log="$D/.testlog"
no_slow=1; grep -qs ' slow ' "$log" && no_slow=0
fast_ran=0; grep -qs ' unit ' "$log" && fast_ran=1
report="$(ls -t "$D"/qa-full-reports/*.md 2>/dev/null | head -1)"
verdict=0
if [ -n "$report" ] && qfl_has_verdict "$report" && grep -Eq '^#+[[:space:]]*VERDICT:.*SHIP-READY' "$report" && ! grep -Eq 'VERDICT:.*pending whole suite' "$report"; then verdict=1; fi
# No whole-suite question: no QUESTION:/AskUserQuestion, and no line mentioning the
# suite that asks anything (a "?"). A plain "Run the whole suite once" statement passes.
no_question=1
grep -qs '^QUESTION:' "$MSG" && no_question=0
grep -Eqis 'AskUserQuestion' "$MSG" && no_question=0
grep -Eqis 'suite.*\?' "$MSG" && no_question=0
echo "no_slow_tier=$no_slow"; echo "verdict_ship_ready=$verdict"; echo "no_suite_question=$no_question"; echo "fast_tier_ran=$fast_ran"
[ $no_slow = 1 ] && [ $verdict = 1 ] && [ $no_question = 1 ] && [ $fast_ran = 1 ] && echo pass=1 || echo pass=0
