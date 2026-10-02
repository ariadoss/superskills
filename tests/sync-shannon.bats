#!/usr/bin/env bats
# Guards for scripts/sync-shannon.sh — the deliberate-only refresh path for
# the vendored Shannon snapshot. The guards run hermetically (no network):
# upgrades must name a tag, must not silently discard local vendor edits, and
# the script must say what the follow-ups are. The clone itself is exercised
# by a maintainer running the real refresh, never by ./tests/run.sh.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SYNC="$REPO_ROOT/scripts/sync-shannon.sh"
}

@test "the sync script exists and is executable" {
  [ -x "$SYNC" ] || { echo "missing or non-executable: $SYNC"; return 1; }
}

@test "a refresh without --tag is refused — upgrades are never 'latest'" {
  run "$SYNC"
  [ "$status" -ne 0 ] || { echo "sync must refuse to run tagless"; return 1; }
  grep -q 'deliberate' <<<"$output" || false
}

@test "the sync script wires the contract test and the rebuild as follow-ups" {
  # The script's job ends at the swap; these strings are how a maintainer
  # learns what makes the refresh real. Losing them re-introduces silent drift.
  grep -qF 'tests/shannon-vendor.bats' "$SYNC" || false
  grep -qF 'shannon-agent-driven.sh prepare' "$SYNC" || false
  grep -qF 'uncommitted changes' "$SYNC" || false
}

@test "a refresh refuses to discard uncommitted vendor edits, before any clone" {
  # The dirty-tree refusal is the only guard between a maintainer's local
  # vendor edits and the script's rm -rf; it runs before any network access,
  # so it is behaviorally testable in a fixture git repo.
  FIX="$BATS_TEST_TMPDIR/repo"
  git init -q "$FIX"
  git -C "$FIX" config user.email t@t; git -C "$FIX" config user.name t
  mkdir -p "$FIX/scripts" "$FIX/vendor/shannon"
  cp "$SYNC" "$FIX/scripts/sync-shannon.sh"
  echo x > "$FIX/vendor/shannon/f"
  git -C "$FIX" add -A; git -C "$FIX" commit -qm init
  echo dirty > "$FIX/vendor/shannon/f"
  run "$FIX/scripts/sync-shannon.sh" --tag v9.9.9
  [ "$status" -ne 0 ] || { echo "sync must refuse a dirty vendor tree"; return 1; }
  grep -q 'uncommitted changes' <<<"$output" || false
  grep -q dirty "$FIX/vendor/shannon/f" || false   # the edit survived
}
