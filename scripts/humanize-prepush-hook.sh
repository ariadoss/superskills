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
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
# Scope is the STOREFRONT text only: the repo-root README.md (and any
# README.*.md at the root) — the GitHub-facing page. Everything else is
# out of scope: skill bodies are agent-to-agent register (frequently
# eval-bound; a rewrite would falsify measured adoption evidence), and
# internal docs/reports/plans are working records, not public prose.
files="$( { git diff --name-only @{push}..HEAD 2>/dev/null \
             || git diff --name-only "origin/${branch:-main}..HEAD" 2>/dev/null \
             || git diff --name-only origin/HEAD..HEAD 2>/dev/null; } \
           | grep -E '^README(\.[\w-]+)?\.md$' || true )"
[ -n "$files" ] || exit 0

# Scan prose, not code or URLs: strip inline-code spans and link targets
# into temp copies so `/command` names and repo URLs cannot false-positive
# (the scanner counts bare words regardless of markdown context).
tmpdir="$(mktemp -d 2>/dev/null)" || exit 0
trap '[ -n "$tmpdir" ] && rm -rf "$tmpdir"' EXIT
scan_args=""
for f in $files; do
  [ -f "$f" ] || continue
  t="$tmpdir/$(printf '%s' "$f" | tr '/' '_')"
  sed -e 's/`[^`]*`//g' -e 's/(https\?:\/\/[^)]*)//g' "$f" > "$t" 2>/dev/null || continue
  scan_args="$scan_args $t"
done
[ -n "$scan_args" ] || exit 0
EXEMPT_FLAG=""
[ -f "$ROOT/.humanize-exempt.txt" ] && EXEMPT_FLAG="--exempt $ROOT/.humanize-exempt.txt"
report="$(python3 "$SCANNER" $scan_args $EXEMPT_FLAG 2>/dev/null)" || exit 0

# Verdict from the report — HIGH-PRECISION signals only. The unambiguous
# AI-slop markers block on any hit: EQ-BENCH slop words/bigrams and phrase
# clichés. The slop_index is density-noisy for technical READMEs (domain
# nouns like "harness"/"integrates" are the product's own vocabulary), so
# only a heavy density (index >= 10) blocks. Word/bigram/trigram counts
# alone do NOT block.
dirty=0
if printf '%s' "$report" | grep -qE '^— (EQ-BENCH SLOP (WORDS|BIGRAMS)|SLOP PHRASE CLICHÉS|CLICHÉ SIMILES)[^:]*:' \
   && ! printf '%s' "$report" | grep -qE '^— (EQ-BENCH SLOP (WORDS|BIGRAMS)|SLOP PHRASE CLICHÉS|CLICHÉ SIMILES)[^:]*: none'; then
  dirty=1
fi
idx="$(printf '%s' "$report" | sed -n 's/.*slop_index = \([0-9.]*\) .*/\1/p' | head -1)"
if [ -n "$idx" ]; then
  [ "$(python3 -c "print(1 if float('$idx') >= 10 else 0)" 2>/dev/null)" = "1" ] && dirty=1
fi
[ "$dirty" -eq 1 ] || exit 0

jq -n --arg r "$report" --arg f "$files" '{
  decision: "block",
  reason: ("humanize pre-push gate: slop flags in the .md files this push would carry:\n" + $f + "\n\n" + $r + "\n\nRun /humanize on the flagged files (its surgical pass handles eval-bound and historical text; the deterministic rewrite alone must not touch measured bindings). If this wording is deliberately held (eval-bound, vendored, or historical), push again with HUMANIZE_PREPUSH=0 in the environment.")
}' 2>/dev/null || exit 0
