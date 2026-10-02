#!/usr/bin/env bash
# export-repomap.sh [OUTDIR] — regenerate the six slash-command markdown files
# of the public ariadoss/repomap repo from this repo, which is their single
# source of truth. The old pull direction (which copied the public repo's
# files INTO skills/) is retired: the skills are edited, tested, and linked by
# ./setup here, and pushed out before a release.
#
# Deliberately a pure copy: each skills/<name>/SKILL.md lands as <name>.md at
# the target root, byte-identical, frontmatter and all. No path rewriting, no
# stripping — a transformation step is the thing that drifts, and a rewrite
# that half-applies produces a repo whose docs lie.
#
# Aux-file policy — the export owns ONLY the six <name>.md paths. The public
# repo is a standalone Python project (README.md, LICENSE, setup,
# requirements.txt, dbmap/, repomap/, scripts/, tests/) and those files are
# NOT generated here: they live in the public checkout and are edited there
# via PR. This script never creates, overwrites, or removes them, so a real
# git checkout of the public repo keeps its .git, README, and tooling intact
# across re-exports.
#
# Idempotent: it removes only the paths it owns, so re-running over a real git
# checkout leaves .git and anything else in place.
#
# Verification: export-humanize.sh proves its export by running the exported
# tree's own tests. This export ships six markdown files with no runnable
# tests of their own, so the equivalent proof is the byte-identity self-check
# below — the export refuses to finish unless every copied file cmps equal to
# its source. tests/export-repomap.bats pins the same invariants.
set -euo pipefail

SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$SRC_ROOT/dist/repomap}"
. "$SRC_ROOT/scripts/lib/export-lib.sh"

SKILLS=(
    dbmap
    repomap
    dbmap-auto-on
    dbmap-auto-off
    repomap-auto-on
    repomap-auto-off
)

# Fail before writing anything if any source skill is missing: a partial
# export must never look publishable.
for name in "${SKILLS[@]}"; do
  [ -f "$SRC_ROOT/skills/$name/SKILL.md" ] || {
    echo "no skill at $SRC_ROOT/skills/$name/SKILL.md" >&2
    exit 1
  }
done

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd -P)"
# The export rewrites the six <name>.md files under OUT, so OUT must not
# overlap the source tree in either direction (shared guard).
export_refuse_source_overlap || exit 1

# Only our own outputs are cleared; a .git directory, the public repo's
# README/LICENSE/code, and any local notes survive.
for name in "${SKILLS[@]}"; do
  rm -f "$OUT/$name.md"
  cp "$SRC_ROOT/skills/$name/SKILL.md" "$OUT/$name.md"
done

# The export is only good if the copy is exact, so prove it here rather than
# discovering it after a push.
for name in "${SKILLS[@]}"; do
  cmp -s "$SRC_ROOT/skills/$name/SKILL.md" "$OUT/$name.md" || {
    echo "export FAILED: $OUT/$name.md is not byte-identical to skills/$name/SKILL.md — not publishable" >&2
    exit 1
  }
done

printf 'exported to %s (%s skills, byte-identical to skills/<name>/SKILL.md)\n' \
  "$OUT" "${#SKILLS[@]}"
