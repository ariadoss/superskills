#!/usr/bin/env bash
# Grade the two-turn deep-interview case in
# evals/reports/2026-11-15-omc-writeplan-intake-PREREG.md.
# Usage: omc-deepinterview-grade.sh RUN_DIR TURN1_MESSAGE FINAL_MESSAGE
set -u

D="${1:?run directory}"; FIRST="${2:?first-turn message}"; FINAL="${3:?final message}"
if [ ! -f "$FIRST" ] || [ ! -f "$FINAL" ]; then
  echo 'missing-message=1'
  echo 'pass=0'
  exit 0
fi

questions="$(grep -o '?' "$FIRST" | wc -l | tr -d ' ')"
spec_count=0; spec=""
for candidate in "$D"/docs/superpowers/specs/*.md; do
  [ -f "$candidate" ] || continue
  spec_count=$((spec_count + 1))
  spec="$candidate"
done

pending=0; checkable=0
if [ "$spec_count" -eq 1 ]; then
  grep -q '^Status: pending approval$' "$spec" && pending=1
  awk '
    /^## Acceptance criteria[[:space:]]*$/ { section=1; next }
    /^## / && section { section=0 }
    section && /^- \[ \] / {
      count++
      item=tolower($0)
      sub(/^- \[ \] /, "", item)
      split(item, words, /[[:space:]]+/)
      if (words[1] !~ /^(run|verify|assert|check|measure|confirm|record|compare|observe|test|submit|open|request|query)$/) bad++
    }
    END { exit !(count > 0 && bad == 0) }
  ' "$spec" && checkable=1
fi

extra=0
if git -C "$D" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r line; do
    path="${line:3}"
    case "$path" in
      docs/superpowers/specs/*|turn1-message.md|final-message.md) ;;
      *) extra=1 ;;
    esac
  done < <(git -C "$D" -c core.quotepath=false status --porcelain --untracked-files=all)
else
  extra=1
fi

echo "questions=$questions spec_count=$spec_count pending=$pending checkable=$checkable extra_files=$extra"
[ "$questions" -eq 1 ] && [ "$spec_count" -eq 1 ] && [ "$pending" -eq 1 ] && [ "$checkable" -eq 1 ] && [ "$extra" -eq 0 ] && echo 'pass=1' || echo 'pass=0'
