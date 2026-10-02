#!/usr/bin/env bash
# sync-clearwing.sh — deliberately refresh vendor/clearwing to a new upstream
# revision. The snapshot is the contract reference for skills/pentest Modes
# 2-4 (the runtime is the installed binary); refreshes are maintainer-only
# and never automatic, exactly like vendor/shannon (see that UPSTREAM).
#
# IMPORTANT: clearwing's version string is ambiguous upstream — tag v1.0.0
# points at an older commit than the code that reports 1.0.0 — so this
# script pins by COMMIT (or tag, resolved to its commit) and the refreshed
# UPSTREAM keeps the pin-by-commit warning.
#
# What it does:
#   1. Refuse unless --rev is given (deliberate upgrades only) and the working
#      tree has no uncommitted changes under vendor/clearwing.
#   2. Fetch that revision shallowly, strip .git, swap the tree in, and
#      regenerate UPSTREAM with the new pin.
#   3. Remind — never run — the follow-ups: ./tests/run.sh (the contract pins
#      in tests/clearwing-vendor.bats must stay green), re-verifying the Mode
#      3 bridge contract against an install of that revision, and re-pinning
#      the local install to the same commit.
#
# Usage: scripts/sync-clearwing.sh --rev <commit-or-tag> [--repo-url https://github.com/Lazarus-AI/clearwing]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$REPO_ROOT/vendor/clearwing"
REPO_URL="https://github.com/Lazarus-AI/clearwing"
REV=""

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --rev) REV="${2:?}"; shift 2 ;;
    --repo-url) REPO_URL="${2:?}"; shift 2 ;;
    *) die "unknown flag: $1 (usage: sync-clearwing.sh --rev <commit-or-tag> [--repo-url <url>])" ;;
  esac
done

[ -n "$REV" ] || die "a --rev is required: upgrades are deliberate, never 'latest' (and clearwing's version string is ambiguous — pin by commit)"

if [ -n "$(git -C "$REPO_ROOT" status --porcelain -- vendor/clearwing 2>/dev/null)" ]; then
  die "vendor/clearwing has uncommitted changes; commit or stash them first"
fi
[ -d "$VENDOR" ] || die "no vendor/clearwing to refresh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/clearwing-sync.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

echo "==> fetching $REPO_URL at $REV"
# Full clone, not shallow: the pin is often a commit rather than a tag, and
# this upstream's tags don't reliably name the code that runs (see header).
# The repo is small; simplicity beats the shallow-fetch edge cases.
git clone --quiet "$REPO_URL" "$TMP/clearwing" || die "clone failed"
git -C "$TMP/clearwing" checkout --quiet --detach "$REV" \
  || die "revision $REV not found upstream"
COMMIT="$(git -C "$TMP/clearwing" rev-parse HEAD)"
DATE="$(git -C "$TMP/clearwing" log -1 --format=%ad --date=short)"

rm -rf "$TMP/clearwing/.git"

echo "==> swapping vendor tree"
rm -rf "$VENDOR"
mv "$TMP/clearwing" "$VENDOR"

cat > "$VENDOR/UPSTREAM" <<EOF
Upstream:   $REPO_URL
Pin:        commit $COMMIT ($DATE)
Version:    whatever the tree reports — AMBIGUOUS upstream: tags have pointed
            at commits other than the code carrying the same version string.
            Pin by commit, never by version string:
            uv tool install --force git+$REPO_URL@$COMMIT
License:    MIT (see LICENSE; vendored unmodified except: .git removed and
            this UPSTREAM note added)
Role:       snapshot + contract reference, NOT the runtime — Mode 3 drives
            the installed \`clearwing\` binary; this tree is what its verified
            behavior was pinned against, and the drift check compares the
            installed commit to it.
Refresh:    scripts/sync-clearwing.sh --rev <commit-or-tag>   (deliberate, never auto)
Contract:   tests/clearwing-vendor.bats pins the facts skills/pentest Mode 3
            relies on; it fails when a refresh breaks the integration surface.
EOF

echo "==> vendored $REV ($COMMIT)"
echo "next, deliberately:"
echo "  1. ./tests/run.sh                                  # contract pins must stay green"
echo "  2. re-verify the Mode 3 bridge contract against an install of this revision"
echo "  3. re-pin the local install to the same commit (line in vendor/clearwing/UPSTREAM)"
echo "  4. update the 'Known-good versions' pin in skills/pentest/SKILL.md"
