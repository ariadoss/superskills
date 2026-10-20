#!/usr/bin/env bash
# humanize-prepush-hook.sh — Claude Code hook (PreToolUse, Bash matcher).
# Gates `git push` on humanize's DETERMINISTIC scan: if any to-be-pushed
# commit touches a user-facing copy file (docs, marketing pages, locale
# strings, UI text; never code, comments, or prompts) whose slop report is
# not clean, block the push
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

# Cheap rejection before the jq fork: this hook sees every Bash tool call.
case "$input" in
  *git*push*) : ;;
  *) exit 0 ;;
esac
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -n "$cmd" ] || exit 0
# A real push: `git [opts] push` at the start of a command or after ; & | ( — not a
# commit message or echo that merely mentions it.
cmd="${cmd//$'\n'/;}"   # a newline separates commands like ;
# Optional wrappers: env assignments (FOO=1), env/sudo/time/exec/command/nohup, an absolute git
# path; option args may be quoted ("my dir"). Followed by push and a word boundary.
push_re='(^|[;&|(]|[[:space:]]then[[:space:]]|[[:space:]]do[[:space:]])[[:space:]]*(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|env|sudo|time|exec|command|nohup)[[:space:]]+)*(/[^[:space:]]*/)?git([[:space:]]+-[^[:space:]]+([[:space:]]+("[^"]*"|\x27[^\x27]*\x27|[^-[:space:]][^[:space:]]*))?)*[[:space:]]+push([[:space:];&)]|$)'
[[ "$cmd" =~ $push_re ]] || exit 0
[ "${HUMANIZE_PREPUSH:-1}" = "0" ] && exit 0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOP="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$TOP" ] && cd "$TOP"
SCANNER="$ROOT/skills/humanize/toolkit/slop_report.py"
USERFACING="$ROOT/skills/humanize/toolkit/userfacing.py"
[ -f "$SCANNER" ] && [ -f "$USERFACING" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# The user-facing files this push would carry that the remote has not seen.
# Try the push upstream first, then the default remote branch; a repo with
# neither has nothing pending — allow.
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
# Gate set: a modified README, and any newly-created (or renamed/copied)
# user-facing file of a supported type. What counts as user-facing is decided
# in one place, toolkit/userfacing.py (deny-list of code, comments, prompts,
# plans, tests, vendored trees; then content type by extension). Modified
# non-README copy is not gated: a hard block on every touch of a legacy page
# punishes the wrong edit. Deletions never gate.
status="$( { git -c core.quotePath=false diff --name-status @{push}..HEAD 2>/dev/null \
              || git -c core.quotePath=false diff --name-status "origin/${branch:-main}..HEAD" 2>/dev/null \
              || git -c core.quotePath=false diff --name-status origin/HEAD..HEAD 2>/dev/null; } || true)"
[ -n "$status" ] || exit 0
files=""
add() { files="${files:+$files$'\n'}$1"; }
# classify prints a type or "none"; a crash prints nothing, which must never read as
# "in scope" (the later extract would fail and the file would pass unscanned, silently).
user_facing() {
  local kind
  kind="$(python3 "$USERFACING" classify "$1" 2>/dev/null)" || kind=""
  if [ -z "$kind" ]; then
    echo "humanize pre-push gate: scan skipped: $1 (could not classify it)" >&2
    return 1
  fi
  [ "$kind" != "none" ]
}
while IFS=$'\t' read -r st p1 p2 _; do
  [ -n "${st:-}" ] || continue
  path="${p2:-$p1}"
  case "$st" in
    M|T)
      case "$(basename "$path")" in
        README*) user_facing "$path" && add "$path" ;;
      esac
      ;;
    A|R[0-9]*|C|C[0-9]*)
      user_facing "$path" && add "$path"
      ;;
  esac
done <<EOF
$(printf '%s\n' "$status")
EOF
[ -n "$files" ] || exit 0

# Scan prose, not code or URLs: userfacing.py extract blanks code blocks,
# inline-code spans, link targets, comments and markup into a temp copy (line
# numbers preserved) so `/command` names and repo URLs cannot false-positive.
# One scanner invocation PER FILE: the scanner reads argv[1] only, so a
# multi-file push would otherwise gate just its first file.
tmpdir="$(mktemp -d 2>/dev/null)" || exit 0
trap '[ -n "$tmpdir" ] && rm -rf "$tmpdir"' EXIT
# Keep the package's vocabulary, and add the current project's reviewed terms.
# Project terms stay in that repository, so one game's feature names do not
# suppress findings in unrelated projects. An array preserves paths with spaces.
EXEMPT_ARGS=()
for exempt_file in "$ROOT/.humanize-exempt.txt" "${TOP:-$ROOT}/.humanize-exempt.txt"; do
  [ -f "$exempt_file" ] || continue
  cat "$exempt_file" >> "$tmpdir/exempt.txt"
  printf '\n' >> "$tmpdir/exempt.txt"
done
[ -f "$tmpdir/exempt.txt" ] && EXEMPT_ARGS=(--exempt "$tmpdir/exempt.txt")
report=""
n=0
while IFS= read -r f; do
  [ -f "$f" ] && [ ! -L "$f" ] || continue
  n=$((n + 1))
  t="$tmpdir/${n}_$(printf '%s' "${f//\//_}")"
  python3 "$USERFACING" extract "$f" > "$t" 2>/dev/null \
    || { echo "humanize pre-push gate: scan skipped: $f (could not extract its text)" >&2; continue; }
  r="$(python3 "$SCANNER" "$t" "${EXEMPT_ARGS[@]}" 2>/dev/null)" \
    || { echo "humanize pre-push gate: scan skipped: $f (scanner failed)" >&2; continue; }
  report="${report:+$report
}$f
$r"
done <<< "$files"
[ -n "$report" ] || exit 0

# Verdict from the report — HIGH-PRECISION signals only. The unambiguous
# AI-slop markers block on any hit: EQ-BENCH slop words/bigrams and phrase
# clichés. The slop_index is density-noisy for technical READMEs (domain
# nouns like "harness"/"integrates" are the product's own vocabulary), so
# only a heavy density (index >= 10) blocks. Word/bigram/trigram counts
# alone do NOT block.
dirty=0
if printf '%s' "$report" | grep -qE '^— (EQ-BENCH SLOP (WORDS|BIGRAMS)|SLOP PHRASE CLICHÉS|CLICHÉ SIMILES)[^:]*: [0-9]'; then
  dirty=1
fi
while IFS= read -r idx; do
  [ -n "$idx" ] || continue
  [ "$(python3 -c "print(1 if float('$idx') >= 10 else 0)" 2>/dev/null)" = "1" ] && dirty=1
done <<< "$(printf '%s' "$report" | sed -n 's/^slop_index = \([0-9.]*\).*/\1/p')"
[ "$dirty" -eq 1 ] || exit 0

jq -n --arg r "$report" --arg f "$files" '{
  decision: "block",
  reason: ("humanize pre-push gate: slop flags in the user-facing docs this push would carry:\n" + $f + "\n\n" + $r + "\n\nRun /humanize on the flagged files. If the flagged wording is deliberate, push again with HUMANIZE_PREPUSH=0 in the environment.")
}' 2>/dev/null || exit 0
