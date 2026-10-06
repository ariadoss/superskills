#!/usr/bin/env bash
# judge.sh [--calibrate] — Layer-1 judge for the /handoff bake-off.
# Scores each note 0 / 0.5 / 1 on five dimensions via one sonnet claude -p
# call returning strict JSON; jq validates; results append to a TSV.
# --calibrate runs the 8 hand-labeled artifacts and prints per-file agreement
# with labels.tsv (adopt the judge only at >=6/8, per the PREREG).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CAL="$ROOT/evals/handoff/_lib/calibration"
OUT="${HANDOFF_JUDGE_TSV:-$ROOT/evals/results/handoff-judge.tsv}"
JUDGE_MODEL="${HANDOFF_JUDGE_MODEL:-sonnet}"

RUBRIC="$(cat <<'R'
You are judging a handoff note written for a fresh agent that will resume a session. The session state it must convey follows the note. Score each dimension 0 (fail), 0.5 (partial), or 1 (pass):

1. self_contained: no line depends on unseen context. No dangling references, no unexplained shorthand, every name resolvable inside the note.
2. actionable: the next steps are executable without re-deriving context. Exact commands and file:line anchors. A step like "continue the migration" scores 0.
3. session_ref: the note carries the session reference block it was given (session file path plus resume command), intact.
4. no_redo: finished work is separated from remaining work with commits or anchors, and known-dead approaches are named where the state has them.
5. discipline: length is proportionate to the state conveyed (roughly 20-80 lines). Padding, or a note far longer than the state it summarizes, scores 0.

Reply with ONE JSON object and nothing else:
{"self_contained":N,"actionable":N,"session_ref":N,"no_redo":N,"discipline":N,"why":"one line"}
R
)"

judge_one() {
  local note="$1" digest="$2" tmp scores why
  tmp="$(mktemp)"
  { printf '%s

SESSION STATE:
' "$RUBRIC"; cat "$digest"; \
    printf '

NOTE UNDER JUDGMENT:
'; cat "$note"; } > "$tmp.all"
  claude -p --model "$JUDGE_MODEL" "$(cat "$tmp.all")" > "$tmp" 2>/dev/null \
    || { rm -f "$tmp" "$tmp.all"; echo "judge call failed for $note" >&2; exit 1; }
  rm -f "$tmp.all"
  jq -e 'has("self_contained") and has("actionable") and has("session_ref") and has("no_redo") and has("discipline") and has("why")' "$tmp" >/dev/null \
    || { echo "invalid judge JSON for $note:" >&2; cat "$tmp" >&2; rm -f "$tmp"; exit 1; }
  scores="$(jq -r '[.self_contained,.actionable,.session_ref,.no_redo,.discipline] | @tsv' "$tmp")"
  why="$(jq -r .why "$tmp")"
  rm -f "$tmp"
  printf '%s\t%s\n' "$scores" "$why"
}

if [ "${1:-}" = "--calibrate" ]; then
  agree=0; total=0
  while IFS=$'\t' read -r f s1 s2 s3 s4 s5 rest; do
    [ -n "$f" ] || continue
    total=$((total+1))
    got="$(judge_one "$CAL/$f.md" "$CAL/mid-refactor-digest.md" | cut -f1-5)"
    want="$(printf '%s\t%s\t%s\t%s\t%s' "$s1" "$s2" "$s3" "$s4" "$s5")"
    if [ "$got" = "$want" ]; then agree=$((agree+1)); echo "MATCH  $f"
    else echo "DIFFER $f: want [$want] got [$got]"; fi
  done < "$CAL/labels.tsv"
  echo "agreement: $agree/$total (adopt judge at >=6/8)"
  [ "$agree" -ge 6 ] || exit 1
  exit 0
fi

for f in "$ROOT"/evals/results/handoff-gen/*.md; do
  [ -s "$f" ] || continue
  base="$(basename "$f" .md)"
  scenario="${base%-r*}"
  [ -f "$ROOT/evals/handoff/_lib/scenarios/$scenario.md" ] || continue
  judge_one "$f" "$ROOT/evals/handoff/_lib/scenarios/$scenario.md" | sed "s/^/$base\t/" >> "$OUT"
  echo "judged $base"
done
