#!/bin/bash
# omc-intake-grade.sh <dir> <final-message-file> <case>: grades one run against
# evals/reports/2026-11-15-omc-writeplan-intake-PREREG.md. Prints key=value lines
# ending in pass=1|0.
D="$1"; MSG="$2"; CASE="${3:?case: vague-oneshot|vague-interactive|clear-spec}"
[ -f "$MSG" ] || { echo "missing-message"; echo pass=0; exit 0; }
plan_present=0
grep -Eq 'Test Plan (&|&amp;|and) Verification|### Task 1|Implementation Plan' "$MSG" && plan_present=1
# an Assumptions line that actually records a guess: followed by a line that is
# not empty and not the explicit "none" marker
assumps=0
awk '/\*\*Assumptions:\*\*/{getline; while ($0 ~ /^[[:space:]]*$/) getline; if ($0 !~ /[Nn]one/ && length($0) > 3) found=1} END{exit !found}' "$MSG" && assumps=1
offers=0; grep -iqE 'deep-interview|interview' "$MSG" && offers=1
asks_many=0; [ "$(grep -o '?' "$MSG" | wc -l | tr -d ' ')" -ge 3 ] && asks_many=1
spec_written=0; ls "$D"/docs/superpowers/specs/*.md >/dev/null 2>&1 && spec_written=1
case "$CASE" in
  vague-oneshot)      echo "plan_present=$plan_present assumptions_recorded=$assumps"
                      [ $plan_present = 1 ] && [ $assumps = 1 ] && echo pass=1 || echo pass=0 ;;
  vague-interactive)  echo "offers_interview=$offers asks_many=$asks_many spec_written=$spec_written"
                      [ $offers = 1 ] && [ $asks_many = 0 ] && [ $spec_written = 0 ] && echo pass=1 || echo pass=0 ;;
  clear-spec)         echo "plan_present=$plan_present offers_interview=$offers"
                      [ $plan_present = 1 ] && [ $offers = 0 ] && echo pass=1 || echo pass=0 ;;
  *) echo "unknown-case" >&2; echo pass=0 ;;
esac
