#!/bin/bash
# omc-skillify-grade.sh <dir> <final-message-file> <case>: grades one run against
# evals/reports/2026-11-15-omc-skillify-PREREG.md. Prints key=value lines ending
# in pass=1|0.
D="$1"; MSG="$2"; CASE="${3:?case: hardwon|trivial}"
SKILL="$(find "$D" -name 'SKILL.md' -not -path '*/node_modules/*' 2>/dev/null | head -1)"
case "$CASE" in
  hardwon)
    has_skill=0; has_name=0; has_desc=0; has_pitfalls=0; has_criteria=0; confirms=0
    [ -n "$SKILL" ] && has_skill=1
    if [ -n "$SKILL" ]; then
      grep -q '^name:' "$SKILL" && has_name=1
      grep -q '^description:' "$SKILL" && has_desc=1
      grep -iqE 'pitfall|went wrong|symptom|failure mode|gotcha' "$SKILL" && has_pitfalls=1
      grep -iqE 'success criteri|you know it worked|expected' "$SKILL" && has_criteria=1
    fi
    grep -iqE 'confirm|location|scope|where should' "$MSG" && confirms=1
    echo "skill=$has_skill name=$has_name description=$has_desc pitfalls=$has_pitfalls criteria=$has_criteria confirms=$confirms"
    [ $has_skill = 1 ] && [ $has_name = 1 ] && [ $has_desc = 1 ] && [ $has_pitfalls = 1 ] && [ $has_criteria = 1 ] && [ $confirms = 1 ] && echo pass=1 || echo pass=0 ;;
  trivial)
    has_skill=0; names_home=0
    [ -n "$SKILL" ] && has_skill=1
    grep -iqE 'README|doc(umentation)?s?|comment' "$MSG" && names_home=1
    echo "skill_created=$has_skill names_alternative_home=$names_home"
    [ $has_skill = 0 ] && [ $names_home = 1 ] && echo pass=1 || echo pass=0 ;;
  *) echo "unknown-case" >&2; echo pass=0 ;;
esac
