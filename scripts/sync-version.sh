#!/usr/bin/env bash
# sync-version.sh — propagate the canonical VERSION into every plugin manifest
# so each tool's native update detector sees the new version on bump:
#   - Claude Code: .claude-plugin/plugin.json + marketplace.json  → startup
#     "Plugins updated, run /reload-plugins" alert
#   - Codex CLI:   .codex-plugin/plugin.json
#   - Cursor:      .cursor-plugin/plugin.json + marketplace.json
#   - marketing-skills/.claude-plugin/plugin.json is regenerated from the tree
#     by scripts/sync-marketing-manifest.sh (its skills list is derived, not stamped)
#
# VERSION (repo root) is the single source of truth. Run this as part of every
# release, right after bumping VERSION and before committing (see CLAUDE.md).
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/version-lib.sh
. "$ROOT/scripts/lib/version-lib.sh"

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[ -n "$VERSION" ] || { echo "ERROR: VERSION file is empty" >&2; exit 1; }

echo "Syncing manifests to VERSION=$VERSION"
rc=0
for f in "${SUPERSKILLS_MANIFESTS[@]}"; do
  if stamp_json_version "$VERSION" "$ROOT/$f"; then
    echo "  [ok]   $f → $VERSION"
  else
    echo "  [skip] $f (missing or no \"version\" field)"
    rc=1
  fi
done
"$ROOT/scripts/sync-marketing-manifest.sh" || rc=1
exit $rc
