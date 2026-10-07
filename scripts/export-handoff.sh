#!/usr/bin/env bash
# export-handoff.sh [OUTDIR] — assemble the standalone `handoff` repo tree
# from this repo, which is the single source of truth for the skill.
# Mirrors export-humanize.sh deliberately: a pure copy (plus one documented
# relocation), git-allowlisted, self-verifying (bats runs in the exported
# tree before the export claims to be publishable).
set -euo pipefail
SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$SRC_ROOT/dist/handoff}"
. "$SRC_ROOT/scripts/lib/export-lib.sh"

SKILL_DIR="$SRC_ROOT/skills/handoff"
[ -f "$SKILL_DIR/SKILL.md" ] || { echo "no skill at $SKILL_DIR" >&2; exit 1; }
[ -f "$SKILL_DIR/scripts/session-ref.sh" ] || { echo "no session-ref at $SKILL_DIR/scripts" >&2; exit 1; }

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd -P)"
export_refuse_source_overlap || exit 1
rm -rf "$OUT/scripts" "$OUT/hooks" "$OUT/tests"
mkdir -p "$OUT/scripts" "$OUT/hooks" "$OUT/tests"

# A symlinked destination would redirect the copy outside the guarded OUT
# tree; refuse rather than follow.
for dest in SKILL.md scripts/session-ref.sh hooks/handoff-trigger-hook.sh tests/handoff-session-ref.bats LICENSE README.md .gitignore NOTICE.md; do
  [ ! -L "$OUT/$dest" ] || { echo "refusing symlinked export destination: $OUT/$dest" >&2; exit 1; }
done

cp "$SKILL_DIR/SKILL.md"                     "$OUT/SKILL.md"
# The one relocation: the skill's internal scripts/ dir becomes the public
# repo's scripts/ (the exported bats file's dual-path lookup covers both).
cp "$SKILL_DIR/scripts/session-ref.sh"       "$OUT/scripts/session-ref.sh"
chmod +x "$OUT/scripts/session-ref.sh"
# The trigger hook ships for standalone users (documented in the README).
cp "$SRC_ROOT/scripts/handoff-trigger-hook.sh" "$OUT/hooks/handoff-trigger-hook.sh"
chmod +x "$OUT/hooks/handoff-trigger-hook.sh"
cp "$SRC_ROOT/tests/handoff-session-ref.bats" "$OUT/tests/"
cp "$SRC_ROOT/tests/handoff-trigger-hook.bats" "$OUT/tests/"
cp "$SRC_ROOT/LICENSE"                       "$OUT/LICENSE"
cp "$SRC_ROOT/scripts/handoff-dist/README.md"   "$OUT/README.md"
cp "$SRC_ROOT/scripts/handoff-dist/.gitignore"  "$OUT/.gitignore"
cp "$SRC_ROOT/scripts/handoff-dist/NOTICE.md"   "$OUT/NOTICE.md"

command -v bats >/dev/null 2>&1 || {
  echo "bats is required to verify the export (brew install bats-core); $OUT is NOT publishable" >&2
  exit 1
}
if bats "$OUT/tests" >/dev/null 2>&1; then
  verdict="tests pass in the exported tree (session-ref + trigger hook)"
else
  echo "export FAILED its own tests at $OUT — not publishable" >&2
  bats "$OUT/tests" >&2 || true
  exit 1
fi

printf 'exported to %s (%s files, %s)\n  %s\n' \
  "$OUT" "$(find "$OUT" -type f -not -path '*/.git/*' | wc -l | tr -d ' ')" \
  "$(du -sh "$OUT" 2>/dev/null | cut -f1)" "$verdict"
