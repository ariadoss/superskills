#!/usr/bin/env bash
# export-dbmap.sh [OUTDIR] — regenerate the two slash-command markdown files
# (the dbmap skill and its auto-off toggle) of the public ariadoss/dbmap repo
# from this repo, which is their single source of truth. History: these
# exported to ariadoss/repomap until that repo's deprecation (2026-10-07);
# /repomap itself was removed from superskills 2.39.0 after five eval-gated
# experiments measured no agent-context utility (evals/reports/2026-10-06/07). The old pull direction (which copied the public repo's
# files INTO skills/) is retired: the skills are edited, tested, and linked by
# ./setup here, and pushed out before a release. /dbmap-auto-on was folded
# into /dbmap's final step (2.45.0) — auto-update is offered where DBMAP.md
# is generated, not toggled by a standalone command — so the export ships the
# skill plus the opt-out and RETIRED below scrubs the folded command's file
# from existing public checkouts.
#
# Deliberately a pure copy: each skills/<name>/SKILL.md lands as <name>.md at
# the target root, byte-identical, frontmatter and all. No path rewriting, no
# stripping — a transformation step is the thing that drifts, and a rewrite
# that half-applies produces a repo whose docs lie.
#
# Aux-file policy — the export owns ONLY its SKILLS and RETIRED <name>.md
# paths. The public repo is a standalone Python project (README.md, LICENSE,
# setup, requirements.txt, dbmap/, repomap/, scripts/, tests/) and those files
# are NOT generated here: they live in the public checkout and are edited
# there via PR. This script never creates, overwrites, or removes them, so a
# real git checkout of the public repo keeps its .git, README, and tooling
# intact across re-exports.
#
# Idempotent: it removes only the paths it owns, so re-running over a real git
# checkout leaves .git and anything else in place.
#
# Verification: export-humanize.sh proves its export by running the exported
# tree's own tests. This export ships two markdown files with no runnable
# tests of their own, so the equivalent proof is the byte-identity self-check
# below — the export refuses to finish unless every copied file cmps equal to
# its source. tests/export-dbmap.bats pins the same invariants.
set -euo pipefail

SRC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$SRC_ROOT/dist/dbmap}"
. "$SRC_ROOT/scripts/lib/export-lib.sh"

SKILLS=(
    dbmap
    dbmap-auto-off
)
# Commands this repo no longer ships: their <name>.md is removed from the
# target but never written.
RETIRED=(
    dbmap-auto-on
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
# The export rewrites its own <name>.md files under OUT, so OUT must not
# overlap the source tree in either direction (shared guard).
export_refuse_source_overlap || exit 1

# Only our own outputs are cleared; a .git directory, the public repo's
# README/LICENSE/code, and any local notes survive.
for name in "${SKILLS[@]}" "${RETIRED[@]}"; do
  rm -f "$OUT/$name.md"
done
for name in "${SKILLS[@]}"; do
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
