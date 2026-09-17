#!/usr/bin/env bash
# sync-marketing-manifest.sh — regenerate the superskills-marketing plugin:
# marketing-skills/plugin-skills/ (one symlink per skill, named by frontmatter
# name) and marketing-skills/.claude-plugin/plugin.json. Run after adding,
# moving or renaming a marketing skill (scripts/sync-version.sh runs it too).
# tests/manifest-lib.bats fails when the committed shim tree drifts.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/manifest-lib.sh
. "$ROOT/scripts/lib/manifest-lib.sh"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[ -n "$VERSION" ] || { echo "ERROR: VERSION file is empty" >&2; exit 1; }
MK="$ROOT/marketing-skills"
# Walk the tree once; both writers and the summary use the same entries.
ENTRIES="$(skill_entries "$MK")"
COUNT="$(printf '%s\n' "$ENTRIES" | grep -c .)"
write_marketing_shims "$MK" "$ENTRIES"
write_marketing_manifest "$MK" "$VERSION" "$MK/.claude-plugin/plugin.json" "$COUNT"
echo "  [ok]   marketing-skills/.claude-plugin/plugin.json → $VERSION ($COUNT skills via plugin-skills/)"
