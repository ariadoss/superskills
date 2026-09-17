#!/usr/bin/env bats
# ./setup's flag handling. An unrecognised flag or --help must never fall
# through to a full install (it once ran a real install during a review probe).
# HOME is a temp dir, and every case exits before anything is written.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
}

@test "setup --help prints usage and exits 0 without installing anything" {
  run bash "$REPO_ROOT/setup" --help
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"Usage"* ]] || false
  [ -z "$(ls -A "$HOME")" ] || { ls -A "$HOME"; return 1; }
}

@test "setup -h is the same as --help" {
  run bash "$REPO_ROOT/setup" -h
  [ "$status" -eq 0 ] || false
  [ -z "$(ls -A "$HOME")" ] || false
}

@test "an unknown flag exits 2 with a message and installs nothing" {
  run bash "$REPO_ROOT/setup" --bogus
  [ "$status" -eq 2 ] || false
  [[ "$output" == *"unknown option: --bogus"* ]] || false
  [ -z "$(ls -A "$HOME")" ] || false
}

@test "--extend-from without a value exits 2 instead of consuming nothing" {
  run bash "$REPO_ROOT/setup" --extend-from
  [ "$status" -eq 2 ] || false
  [ -z "$(ls -A "$HOME")" ] || false
}

@test "setup logs prunes for every tool it links into (no silent removal)" {
  run grep -c 'prune_dangling_links .*>/dev/null' "$REPO_ROOT/setup"
  [ "$output" -eq 0 ] || false
}
