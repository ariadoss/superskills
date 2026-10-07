#!/usr/bin/env bash
# humanize-prepush-hook.sh — Claude Code hook (PreToolUse, Bash matcher).
# Gates `git push` on humanize's DETERMINISTIC scan: if any to-be-pushed
# commit touches a .md file whose slop report is not clean, block the push
# with the report and the instruction to run /humanize (whose surgical,
# judgement-bearing pass — exemptions for eval-bound and historical text —
# is exactly what a hook cannot do). Never breaks a push on tooling
# failure: any error degrades to silent allow.
#
# Bypass: HUMANIZE_PREPUSH=0 in the environment disables the gate entirely
# (the honest escape for eval-bound wording, where a deterministic rewrite
# would falsify measured bindings).
set -u
input="$(cat 2>/dev/null || true)"
[ -n "$input" ] || exit 0

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -n "$cmd" ] || exit 0
case "$cmd" in
  *git[[:space:]]push*) : ;;
  *) exit 0 ;;
esac
[ "${HUMANIZE_PREPUSH:-1}" = "0" ] && exit 0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCANNER="$ROOT/skills/humanize/toolkit/slop_report.py"
[ -f "$SCANNER" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# The .md files this push would carry that the remote has not seen.
# Try the push upstream first, then the default remote branch; a repo with
# neither has nothing pending — allow.
files="$( { git diff --name-only @{push}..HEAD 2>/dev/null || git diff --name-only origin/HEAD..HEAD 2>/dev/null; } | grep '\.md$' || true )"
[ -n "$files" ] || exit 0

report="$(python3 "$SCANNER" $files 2>/dev/null)" || exit 0

# Verdict from the report: the slop_index word/bigram/trigram counts, and
# the EQ-BENCH groups' none-lines. Anything nonzero/non-none blocks.
wbt="$(printf '%s' "$report" | sed -n 's/.*slop_index = [0-9.]*  \[word \([0-9]*\), bigram \([0-9]*\), trigram \([0-9]*\)\].*/\1 \2 \3/p' | head -1)"
dirty=0
if [ -n "$wbt" ]; then
  set -- $wbt
  [ "$1" -gt 0 ] || [ "$2" -gt 0 ] || [ "$3" -gt 0 ] && dirty=1
fi
if printf '%s' "$report" | grep -qE '^— (EQ-BENCH SLOP (WORDS|BIGRAMS|TRIGRAMS)|SLOP PHRASE CLICHÉS)[^:]*:' && \
   ! printf '%s' "$report" | grep -qE '^— (EQ-BENCH SLOP (WORDS|BIGRAMS|TRIGRAMS)|SLOP PHRASE CLICHÉS)[^:]*: none'; then
  dirty=1
fi
[ "$dirty" -eq 1 ] || exit 0

jq -n --arg r "$report" --arg f "$files" '{
  decision: "block",
  reason: ("humanize pre-push gate: slop flags in the .md files this push would carry:\n" + $f + "\n\n" + $r + "\n\nRun /humanize on the flagged files (its surgical pass handles eval-bound and historical text; the deterministic rewrite alone must not touch measured bindings). If this wording is deliberately held (eval-bound, vendored, or historical), push again with HUMANIZE_PREPUSH=0 in the environment.")
}' 2>/dev/null || exit 0
