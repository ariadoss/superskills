#!/usr/bin/env bats
# Guards for scripts/sync-clearwing.sh — the deliberate-only refresh path for
# the vendored clearwing snapshot. Hermetic (no network): upgrades must name a
# revision, must warn about the ambiguous version string, and must wire the
# follow-ups. The clone itself is a maintainer action, never run by tests.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SYNC="$REPO_ROOT/scripts/sync-clearwing.sh"
}

@test "the sync script exists and is executable" {
  [ -x "$SYNC" ] || { echo "missing or non-executable: $SYNC"; return 1; }
}

@test "a refresh without --rev is refused — upgrades are never 'latest'" {
  run "$SYNC"
  [ "$status" -ne 0 ] || { echo "sync must refuse to run revisionless"; return 1; }
  grep -q 'deliberate' <<<"$output" || false
}

@test "the sync script pins by COMMIT and says why" {
  # clearwing's version string is ambiguous upstream; a sync that forgot the
  # warning would invite pinning by a lying version number.
  grep -qF 'AMBIGUOUS' "$SYNC" || false
  grep -qF 'Pin:        commit' "$SYNC" || false
  grep -qF 'uncommitted changes' "$SYNC" || false
}

@test "the sync script wires the follow-ups that make a refresh real" {
  grep -qF 'tests/clearwing-vendor.bats' "$SYNC" || false
  grep -qF 'Known-good versions' "$SYNC" || false
  grep -qF 're-verify the Mode 3 bridge contract' "$SYNC" || false
}
