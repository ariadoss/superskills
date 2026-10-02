#!/usr/bin/env bats
# Unit tests for scripts/check-upstream-drift.sh — the periodic "should we
# upgrade the vendored pentest tools?" check that /daily-qa runs. Hermetic:
# pure functions are exercised with fixture text; the network helpers are
# stubbed. No real HOME, no network.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # shellcheck source=../../scripts/check-upstream-drift.sh
  source "$REPO_ROOT/scripts/check-upstream-drift.sh"
}

LSREMOTE_FIXTURE="$(cat <<'EOF'
3d1a3c75f82d96d0614b74e463d2be101b7804f1	refs/tags/v3.3.0
4be4853fd3110a4097ad8b87dd611b07ed163ce9	refs/tags/v3.2.0^{}
25b90b0611f15ab945e051dfee8ae78600d3a002	refs/tags/v3.3.0
9dcc8b4ae456a1e3a0216295216e3c3509c4dc7c	refs/tags/v1.0.0^{}
a14c7944d87b30ed7bfecd4bad06562e24002b01	refs/heads/main
f4809e3c5f87bc4b053f279f315772907235aaad	refs/tags/v1.0.0
deadbeef	refs/tags/nightly
EOF
)"

@test "latest stable tag ignores peeled ^{} lines, branches, and non-semver tags" {
  run cwdrift_latest_tag "$LSREMOTE_FIXTURE"
  [ "$status" -eq 0 ] || false
  [ "$output" = "v3.3.0" ] || { echo "got: $output"; return 1; }
}

@test "latest stable tag picks the HIGHEST semver, not the last line" {
  local shuffled="$(printf 'x	refs/tags/v1.9.0\nx	refs/tags/v1.10.0\n')"
  run cwdrift_latest_tag "$shuffled"
  [ "$output" = "v1.10.0" ] || { echo "got: $output"; return 1; }
}

@test "an empty or tagless remote yields no tag without failing" {
  run cwdrift_latest_tag "x	refs/heads/main"
  [ "$status" -eq 0 ] || false
  [ -z "$output" ] || { echo "expected nothing, got: $output"; return 1; }
}

@test "UPSTREAM fields parse: Tag for shannon, Pin for clearwing" {
  UP="$BATS_TEST_TMPDIR/UPSTREAM"
  cat > "$UP" <<'EOF'
Upstream:   https://github.com/KeygraphHQ/shannon
Tag:        v3.3.0
Commit:     327c10fd90a6186a9f035b4b6ddb5bbba1839e92 (2026-09-21)
EOF
  run cwdrift_field "$UP" "Tag"
  [ "$output" = "v3.3.0" ] || false
  run cwdrift_field "$UP" "Commit"
  case "$output" in
    327c10fd90a6186a9f035b4b6ddb5bbba1839e92*) : ;;
    *) echo "got: $output"; return 1 ;;
  esac
}

@test "shannon report: equal tags say up to date; newer upstream says upgrade with the exact command" {
  V="$BATS_TEST_TMPDIR/vendor-shannon"; mkdir -p "$V"
  printf 'Upstream:   https://github.com/KeygraphHQ/shannon\nTag:        v3.3.0\n' > "$V/UPSTREAM"
  run cwdrift_shannon_report "$V" "v3.3.0"
  grep -qF 'up to date' <<<"$output" || false
  run cwdrift_shannon_report "$V" "v3.4.0"
  grep -qF 'v3.4.0' <<<"$output" || false
  grep -qF 'sync-shannon.sh --tag v3.4.0' <<<"$output" || false
}

@test "clearwing report: pins compared by COMMIT, and runtime drift is called out separately from upstream drift" {
  V="$BATS_TEST_TMPDIR/vendor-cw"; mkdir -p "$V"
  printf 'Upstream:   https://github.com/Lazarus-AI/clearwing\nPin:        commit 88d3a8a41c22ad9c4d8aaf67bbf5489549740454 (2026-04-24)\n' > "$V/UPSTREAM"
  # Installed == pin, upstream HEAD moved: upgrade available, no runtime drift.
  run cwdrift_clearwing_report "$V" "88d3a8a41c22ad9c4d8aaf67bbf5489549740454" "48a7683c7cd5ddfe2209f123864a07be70d59fc7" "v1.0.0"
  grep -qF '48a7683' <<<"$output" || false
  grep -qF 'sync-clearwing.sh --rev' <<<"$output" || false
  # Installed != pin: the RUNNING tool no longer matches the verified snapshot.
  run cwdrift_clearwing_report "$V" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "48a7683c7cd5ddfe2209f123864a07be70d59fc7" "v1.0.0"
  grep -qF 'RUNTIME DRIFT' <<<"$output" || false
}

@test "offline is unverified, never 'up to date' — never infer success" {
  V="$BATS_TEST_TMPDIR/vendor-shannon"; mkdir -p "$V"
  printf 'Upstream:   https://github.com/KeygraphHQ/shannon\nTag:        v3.3.0\n' > "$V/UPSTREAM"
  run cwdrift_shannon_report "$V" ""
  grep -qF 'unverified' <<<"$output" || false
}
