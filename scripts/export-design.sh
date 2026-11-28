#!/usr/bin/env bash
# export-design.sh [OUTDIR]: assemble the standalone `design-skills` repo tree
# from this repo, which is the single source of truth for the ten design-*
# skills. A pure copy, like the other exports: each design-skills/<name>/
# lands as <name>/SKILL.md, byte-identical. The export owns those ten
# directories plus README.md, LICENSE and .gitignore; everything else in a
# real checkout (.git included) is left alone.
set -euo pipefail
SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$SRC_ROOT/dist/design-skills}"
. "$SRC_ROOT/scripts/lib/export-lib.sh"

SKILLS=(design-principles design-brief design-direction design-variations
        design-prototype design-system-extract design-slop-check
        design-hierarchy design-states design-polish)
DIST="$SRC_ROOT/scripts/design-dist"

for n in "${SKILLS[@]}"; do
  [ -f "$SRC_ROOT/design-skills/$n/SKILL.md" ] || { echo "no skill at design-skills/$n" >&2; exit 1; }
done

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd -P)"
export_refuse_source_overlap || exit 1

# A symlinked destination would redirect the delete and the copy outside the
# guarded OUT tree; refuse rather than follow.
for dest in "${SKILLS[@]}" README.md LICENSE .gitignore; do
  [ ! -L "$OUT/$dest" ] || { echo "refusing symlinked export destination: $OUT/$dest" >&2; exit 1; }
done

for n in "${SKILLS[@]}"; do
  rm -rf "${OUT:?}/$n"
  mkdir -p "$OUT/$n"
  cp "$SRC_ROOT/design-skills/$n/SKILL.md" "$OUT/$n/SKILL.md"
done
cp "$DIST/README.md"  "$OUT/README.md"
cp "$DIST/.gitignore" "$OUT/.gitignore"
cp "$SRC_ROOT/LICENSE" "$OUT/LICENSE"

for n in "${SKILLS[@]}"; do
  cmp -s "$OUT/$n/SKILL.md" "$SRC_ROOT/design-skills/$n/SKILL.md" \
    || { echo "export FAILED: $n/SKILL.md differs from its source" >&2; exit 1; }
done

printf 'exported to %s (%s skills, byte-identical to design-skills/)\n' "$OUT" "${#SKILLS[@]}"
