#!/bin/bash
# omc-sdd-grade.sh <dir> <final-message-file> <question>: grades one run against
# evals/reports/2026-11-15-omc-sdd-contracts-PREREG.md. Prints key=value lines
# ending in pass=1|0.
D="$1"; MSG="$2"; Q="${3:?question: baseline|dispatch|green}"
WS="$D/.superpowers/sdd/fixture-plan"
case "$Q" in
  baseline)
    BL="$(ls "$WS"/feedback-baseline.tsv 2>/dev/null)"
    has_bl=0; right_id=0; said=0
    [ -n "$BL" ] && has_bl=1
    [ -n "$BL" ] && grep -q 'tests/login.test.js::rejects bad token' "$BL" && right_id=1
    grep -iqE 'pre-existing|already (broken|failing|red)|baseline' "$MSG" && said=1
    echo "baseline_exists=$has_bl baseline_has_id=$right_id mentioned=$said"
    [ $has_bl = 1 ] && [ $right_id = 1 ] && [ $said = 1 ] && echo pass=1 || echo pass=0 ;;
  dispatch)
    DISP="$(ls "$WS"/*dispatch* "$WS"/task-2* 2>/dev/null | head -1)"
    refs_handoff=0; refs_report=0; mentions_assump=0
    if [ -n "$DISP" ]; then
      grep -q 'task-1-handoff' "$DISP" && refs_handoff=1
      grep -q 'task-1-report' "$DISP" && refs_report=1
      grep -iqE 'assumption' "$DISP" && mentions_assump=1
    fi
    echo "dispatch_file=${DISP:-none} refs_handoff=$refs_handoff refs_report=$refs_report mentions_assumptions=$mentions_assump"
    [ -n "$DISP" ] && [ $refs_handoff = 1 ] && [ $refs_report = 0 ] && [ $mentions_assump = 1 ] && echo pass=1 || echo pass=0 ;;
  green)
    has_bl=0; ls "$WS"/feedback-baseline.tsv >/dev/null 2>&1 && has_bl=1
    echo "baseline_exists=$has_bl"
    [ $has_bl = 0 ] && echo pass=1 || echo pass=0 ;;
  *) echo "unknown-question" >&2; echo pass=0 ;;
esac
