#!/usr/bin/env bats
# Unit tests for scripts/lib/version-lib.sh — JSON version stamping used by
# scripts/sync-version.sh. Hermetic: fixtures in BATS_TEST_TMPDIR.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/scripts/lib/version-lib.sh"

  ONE="$BATS_TEST_TMPDIR/one.json"
  cat > "$ONE" <<'EOF'
{
  "name": "superskills",
  "version": "1.0.0",
  "description": "x"
}
EOF

  # Two version fields (marketplace-style: a nested plugin entry).
  TWO="$BATS_TEST_TMPDIR/two.json"
  cat > "$TWO" <<'EOF'
{
  "name": "superskills",
  "plugins": [
    { "name": "superskills", "version": "1.0.0", "source": "./" }
  ],
  "version": "1.0.0"
}
EOF

  NOVER="$BATS_TEST_TMPDIR/nover.json"
  cat > "$NOVER" <<'EOF'
{ "name": "superskills" }
EOF
}

ver_of() { grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$1"; }

@test "stamps a single version field" {
  run stamp_json_version "2.12.1" "$ONE"
  [ "$status" -eq 0 ]
  grep -q '"version": "2.12.1"' "$ONE"
  ! grep -q '1.0.0' "$ONE"
}

@test "stamps every version field (marketplace + entry)" {
  stamp_json_version "2.12.1" "$TWO"
  [ "$(ver_of "$TWO" | grep -c '2.12.1')" -eq 2 ]
  ! grep -q '1.0.0' "$TWO"
}

@test "does not touch other fields" {
  stamp_json_version "2.12.1" "$ONE"
  grep -q '"name": "superskills"' "$ONE"
  grep -q '"description": "x"' "$ONE"
}

@test "is idempotent" {
  stamp_json_version "2.12.1" "$ONE"
  run stamp_json_version "2.12.1" "$ONE"
  [ "$status" -eq 0 ]
  [ "$(grep -c '2.12.1' "$ONE")" -eq 1 ]
}

@test "returns 1 when file is missing" {
  run stamp_json_version "2.12.1" "$BATS_TEST_TMPDIR/nope.json"
  [ "$status" -eq 1 ]
}

@test "returns 1 when no version field present" {
  run stamp_json_version "2.12.1" "$NOVER"
  [ "$status" -eq 1 ]
  ! grep -q '2.12.1' "$NOVER"
}

@test "returns 1 on empty version arg" {
  run stamp_json_version "" "$ONE"
  [ "$status" -eq 1 ]
}

@test "stamped JSON is still valid (jq parses it) when jq is available" {
  if ! command -v jq >/dev/null 2>&1; then skip "jq not installed"; fi
  stamp_json_version "2.12.1" "$TWO"
  run jq -e . "$TWO"
  [ "$status" -eq 0 ]
}
