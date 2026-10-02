#!/usr/bin/env bash
# sync-shannon.sh — deliberately refresh vendor/shannon to a new upstream tag.
#
# The vendor snapshot is the drift guard for skills/pentest Mode 5: the scan
# that runs is the committed code, so upstream releases change nothing until
# this script is run BY A MAINTAINER, on purpose. There is no automatic
# upgrade path, by design (vendor/shannon/UPSTREAM records this).
#
# What it does:
#   1. Refuse unless --tag is given (deliberate upgrades only) and the working
#      tree has no uncommitted changes under vendor/shannon (nothing is lost).
#   2. Shallow-clone that tag, strip .git and the two README GIFs (~49MB),
#      swap the tree in, and regenerate UPSTREAM with the new pin.
#   3. Remind — never run — the two follow-ups that make the refresh real:
#      ./tests/run.sh (tests/shannon-vendor.bats pins the integration facts;
#      red means the new tag broke the agent-driven bridge contract) and
#      skills/pentest/shannon-agent-driven.sh prepare (rebuild CLI + image).
#
# Usage: scripts/sync-shannon.sh --tag v3.4.0 [--repo-url https://github.com/KeygraphHQ/shannon]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$REPO_ROOT/vendor/shannon"
REPO_URL="https://github.com/KeygraphHQ/shannon"
TAG=""

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --tag) TAG="${2:?}"; shift 2 ;;
    --repo-url) REPO_URL="${2:?}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    *) die "unknown flag: $1 (usage: sync-shannon.sh --tag <tag> [--repo-url <url>] [--force])" ;;
  esac
done

[ -n "$TAG" ] || die "a --tag is required: upgrades are deliberate, never 'latest'"

# Refuse to discard local edits to the vendored tree.
if [ -n "$(git -C "$REPO_ROOT" status --porcelain -- vendor/shannon 2>/dev/null)" ]; then
  die "vendor/shannon has uncommitted changes; commit or stash them first"
fi
[ -d "$VENDOR" ] || die "no vendor/shannon to refresh (first-time vendor: clone manually, then read vendor/shannon/UPSTREAM)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/shannon-sync.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

echo "==> cloning $REPO_URL at $TAG"
# '--' keeps a dash-prefixed --repo-url value a positional URL, never a git
# option (the same guard setup's knowledge-base clone carries).
git clone --quiet --depth 1 --branch "$TAG" -- "$REPO_URL" "$TMP/shannon" \
  || die "clone failed (does tag $TAG exist upstream?)"
REV="$(git -C "$TMP/shannon" rev-parse HEAD)"
# Tags are mutable upstream: the same tag resolving to a different commit
# than the vendored pin means the label moved — a deliberate refresh must
# say so (--force) or pin the new commit explicitly.
if [ -z "${FORCE:-}" ] && [ -f "$VENDOR/UPSTREAM" ]; then
  PRIOR_TAG="$(sed -n 's/^Tag:[[:space:]]*//p' "$VENDOR/UPSTREAM" | head -1)"
  PRIOR_REV="$(sed -n 's/^Commit:[[:space:]]*//p' "$VENDOR/UPSTREAM" | head -1 | cut -d' ' -f1)"
  if [ "$TAG" = "$PRIOR_TAG" ] && [ -n "$PRIOR_REV" ] && [ "$REV" != "$PRIOR_REV" ]; then
    die "tag $TAG moved: vendored pin is $PRIOR_REV, upstream now resolves to $REV — pass --force to accept, or pin the new commit deliberately"
  fi
fi
DATE="$(git -C "$TMP/shannon" log -1 --format=%ad --date=short)"

# Strip what never belongs in the snapshot: git metadata and README media.
rm -rf "$TMP/shannon/.git" \
       "$TMP/shannon/assets/Shannon3GIF.gif" \
       "$TMP/shannon/assets/shannon-action.gif"
# rm -rf succeeds silently when the path is absent: an upstream rename would
# quietly no-op the ~49MB trim while UPSTREAM keeps claiming the GIFs were
# removed. Surface the drift at sync time instead.
for gone in "$TMP/shannon/assets/Shannon3GIF.gif" "$TMP/shannon/assets/shannon-action.gif"; do
  [ ! -e "$gone" ] || echo "warn: $gone still present after strip — trim list may be stale" >&2
done

echo "==> swapping vendor tree"
rm -rf "$VENDOR"
mv "$TMP/shannon" "$VENDOR"

cat > "$VENDOR/UPSTREAM" <<EOF
Upstream:   $REPO_URL
Tag:        $TAG
Commit:     $REV ($DATE)
License:    AGPL-3.0 (see LICENSE; vendored unmodified except: .git and two
            README GIFs removed for size, and this UPSTREAM note added)
Refresh:    scripts/sync-shannon.sh --tag <new-tag>   (deliberate, never auto)
Contract:   tests/shannon-vendor.bats pins the facts skills/pentest Mode 5
            relies on; it fails when a refresh breaks the integration surface.
EOF

echo "==> vendored $TAG ($REV)"
echo "next, deliberately:"
echo "  1. ./tests/run.sh                     # contract pins must stay green"
echo "  2. skills/pentest/shannon-agent-driven.sh prepare   # rebuild CLI + image"
echo "  3. update the 'Known-good versions' pin in skills/pentest/SKILL.md"
