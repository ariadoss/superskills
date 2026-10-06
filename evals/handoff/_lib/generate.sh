#!/usr/bin/env bash
# generate.sh — produce handoff notes for the bake-off. Idempotent: an
# existing output file is never regenerated (delete it to redo that cell).
# Cost: one `claude -p` call per missing cell; claude -p exposes no per-call
# cap, which is the PREREG's disclosed deviation — the control is this
# driver's fixed, idempotent cell list plus a spend check after each batch.
# Re-verified `claude --help` shows -p before first use (house rule).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="${HANDOFF_GEN_OUT:-$ROOT/evals/results/handoff-gen}"
RUNS="${HANDOFF_GEN_RUNS:-3}"
mkdir -p "$OUT"

# Fixed session reference, embedded like-for-like in every cell so variants
# are compared on content, not on discovery luck. (Command substitution, not
# read -d '': read returns 1 at heredoc EOF and would kill set -e.)
REF_BLOCK="$(cat <<'REF'
SESSION-REF OUTPUT (embed in the note under its session section):
session file: /Users/fixture/.claude/projects/-Users-fixture-repo/44444444-4444-4444-4444-444444444444.jsonl
resume: claude --resume 44444444-4444-4444-4444-444444444444 -p "<prompt>"
fallback: claude -c -p "<prompt>"
REF
)"

for scenario in mid-refactor mid-experiment mid-multibranch mid-writing; do
  for variant in A B C; do
    for r in $(seq 1 "$RUNS"); do
      out="$OUT/$scenario-$variant-r$r.md"
      [ -s "$out" ] && continue
      tmp="$(mktemp)"
      { cat "$ROOT/evals/handoff/_lib/variants/$variant.md"; printf '\n\n'; \
        cat "$ROOT/evals/handoff/_lib/scenarios/$scenario.md"; printf '\n\n'; \
        printf '%s\n' "$REF_BLOCK"; } > "$tmp.prompt"
      claude -p "$(cat "$tmp.prompt")" > "$tmp" 2>/dev/null \
        || { rm -f "$tmp" "$tmp.prompt"; echo "gen failed: $scenario-$variant-r$r" >&2; exit 1; }
      rm -f "$tmp.prompt"
      mv "$tmp" "$out"
      echo "wrote $out"
    done
  done
done
