#!/usr/bin/env bash
# export-humanize.sh [OUTDIR] — assemble the standalone `humanize` repo tree from
# this repo, which is the single source of truth for the skill.
#
# Deliberately a pure copy: the standalone repo names the toolkit directory
# `toolkit/`, exactly as the skill does, and tests/humanize-toolkit.bats locates
# its layout at runtime. So there is no path rewriting anywhere in this script.
# That is the point — a transformation step is the thing that drifts, and a
# rewrite that half-applies produces a repo whose tests pass and whose docs lie.
#
# Idempotent: it removes only the paths it owns, so re-running over a real git
# checkout leaves .git and anything else in place.
set -euo pipefail

SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$SRC_ROOT/dist/humanize}"

SKILL_DIR="$SRC_ROOT/skills/humanize"
[ -f "$SKILL_DIR/SKILL.md" ] || { echo "no skill at $SKILL_DIR" >&2; exit 1; }
[ -d "$SKILL_DIR/toolkit" ] || { echo "no toolkit at $SKILL_DIR/toolkit" >&2; exit 1; }

mkdir -p "$OUT"
# Only our own outputs are cleared; a .git directory or local notes survive.
rm -rf "$OUT/toolkit" "$OUT/tests"
mkdir -p "$OUT/toolkit" "$OUT/tests"

cp "$SKILL_DIR/SKILL.md"                     "$OUT/SKILL.md"
# An allowlist, not a denylist: only toolkit files git tracks (committed or
# staged; their working-tree content is copied) ship. Anything else, be it __pycache__/, a macOS
# .DS_Store, scratch notes or a misnamed secret, stays out of the public tree.
# To publish a new toolkit file, `git add` it first.
( cd "$SKILL_DIR/toolkit" && git ls-files -z -- . ) \
  | while IFS= read -r -d '' f; do
      case "$f" in */*) continue ;; esac       # top level only, as the skill loads it
      cp "$SKILL_DIR/toolkit/$f" "$OUT/toolkit/"
    done
untracked="$(cd "$SKILL_DIR/toolkit" && git ls-files --others --exclude-standard -- . | grep -v / || true)"
[ -z "$untracked" ] || printf '%s\n' "$untracked" | sed 's/^/not exported (untracked; git add to publish): /' >&2
cp "$SRC_ROOT/tests/humanize-toolkit.bats"   "$OUT/tests/"
cp "$SRC_ROOT/LICENSE"                       "$OUT/LICENSE"
cp "$SKILL_DIR/toolkit/NOTICE.md"            "$OUT/NOTICE.md"
cp "$SRC_ROOT/scripts/humanize-dist/README.md"   "$OUT/README.md"
cp "$SRC_ROOT/scripts/humanize-dist/.gitignore"  "$OUT/.gitignore"

# The export is only good if it stands alone, so prove it here rather than
# discovering it after a push. No bats means no proof, so no export.
command -v bats >/dev/null 2>&1 || {
  echo "bats is required to verify the export (brew install bats-core); $OUT is NOT publishable" >&2
  exit 1
}
if bats "$OUT/tests/humanize-toolkit.bats" >/dev/null 2>&1; then
  verdict="tests pass in the exported tree"
else
  echo "export FAILED its own tests at $OUT — not publishable" >&2
  bats "$OUT/tests/humanize-toolkit.bats" >&2 || true
  exit 1
fi

printf 'exported to %s (%s files, %s)\n  %s\n' \
  "$OUT" "$(find "$OUT" -type f -not -path '*/.git/*' | wc -l | tr -d ' ')" \
  "$(du -sh "$OUT" 2>/dev/null | cut -f1)" "$verdict"
