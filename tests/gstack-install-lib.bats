#!/usr/bin/env bats
# Tests for scripts/lib/gstack-install-lib.sh — the gstack install state
# machine used by ./setup. Hermetic: a local bare git repo stands in for
# github.com/garrytan/gstack, and a fake vendor snapshot stands in for
# vendor/gstack. No network.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/scripts/lib/gstack-install-lib.sh"

  # Fake upstream: a bare repo whose working copy has VERSION + a setup script
  # that leaves a marker so tests can see gstack's own setup ran.
  WORK="$BATS_TEST_TMPDIR/upstream-work"
  mkdir -p "$WORK"
  echo "9.9.9.9" > "$WORK/VERSION"
  printf '#!/bin/sh\ntouch "$(dirname "$0")/.setup-ran"\n' > "$WORK/setup"; chmod +x "$WORK/setup"
  echo "# review" > "$WORK/SKILL.md"
  git -C "$WORK" init -q -b main
  git -C "$WORK" -c user.name=t -c user.email=t@t add -A
  git -C "$WORK" -c user.name=t -c user.email=t@t commit -qm init
  UPSTREAM="$BATS_TEST_TMPDIR/upstream.git"
  git clone -q --bare "$WORK" "$UPSTREAM"

  VENDOR="$BATS_TEST_TMPDIR/vendor/gstack"
  mkdir -p "$VENDOR"
  echo "1.15.0.0" > "$VENDOR/VERSION"
  printf '#!/bin/sh\ntouch "$(dirname "$0")/.vendor-setup-ran"\n' > "$VENDOR/setup"; chmod +x "$VENDOR/setup"

  DEST="$BATS_TEST_TMPDIR/skills/gstack"
  export GSTACK_CLONE_BACKOFF=0
}

@test "state: absent / partial / vendor / real" {
  [ "$(gstack_install_state "$DEST")" = "absent" ]
  mkdir -p "$DEST"; touch "$DEST/junk"
  [ "$(gstack_install_state "$DEST")" = "partial" ]
  echo "1.0" > "$DEST/VERSION"; touch "$DEST/.superskills-vendor-copy"
  [ "$(gstack_install_state "$DEST")" = "vendor" ]
  rm "$DEST/.superskills-vendor-copy"; mkdir "$DEST/.git"
  [ "$(gstack_install_state "$DEST")" = "real" ]
}

@test "ensure: clones for real when absent and runs gstack's setup" {
  run gstack_ensure "$DEST" "$VENDOR" "$UPSTREAM"
  [ "$status" -eq 0 ]
  [ -d "$DEST/.git" ]
  [ "$(cat "$DEST/VERSION")" = "9.9.9.9" ]
  [ -f "$DEST/.setup-ran" ]
  [ ! -f "$DEST/.superskills-vendor-copy" ]
  [[ "$output" == *"cloned"* ]]
}

@test "ensure: retries a failing clone before giving up" {
  export GSTACK_CLONE_ATTEMPTS=3
  run gstack_ensure "$DEST" "$VENDOR" "$BATS_TEST_TMPDIR/does-not-exist.git"
  [[ "$output" == *"attempt 3/3"* ]]
}

@test "ensure: falls back to the vendor copy when the clone fails, and marks it" {
  run gstack_ensure "$DEST" "$VENDOR" "$BATS_TEST_TMPDIR/does-not-exist.git"
  [ "$status" -eq 0 ]
  [ "$(cat "$DEST/VERSION")" = "1.15.0.0" ]
  [ -f "$DEST/.superskills-vendor-copy" ]
  [ -f "$DEST/.vendor-setup-ran" ]
  [ ! -d "$DEST/.git" ]
  [[ "$output" == *"vendor copy"* ]]
}

@test "ensure: a vendor-copy install is promoted to a real clone on the next run" {
  gstack_ensure "$DEST" "$VENDOR" "$BATS_TEST_TMPDIR/does-not-exist.git" >/dev/null
  [ "$(gstack_install_state "$DEST")" = "vendor" ]
  run gstack_ensure "$DEST" "$VENDOR" "$UPSTREAM"
  [ "$status" -eq 0 ]
  [ "$(gstack_install_state "$DEST")" = "real" ]
  [ "$(cat "$DEST/VERSION")" = "9.9.9.9" ]
  [ ! -f "$DEST/.superskills-vendor-copy" ]
  [[ "$output" == *"promot"* ]]
}

@test "ensure: a vendor-copy install stays put when the clone still fails" {
  gstack_ensure "$DEST" "$VENDOR" "$BATS_TEST_TMPDIR/does-not-exist.git" >/dev/null
  run gstack_ensure "$DEST" "$VENDOR" "$BATS_TEST_TMPDIR/does-not-exist.git"
  [ "$status" -eq 0 ]
  [ "$(gstack_install_state "$DEST")" = "vendor" ]
  [ "$(cat "$DEST/VERSION")" = "1.15.0.0" ]
  [[ "$output" == *"still on the vendor copy"* ]]
}

@test "ensure: a partial (broken) install is moved aside, not nested into" {
  mkdir -p "$DEST"; touch "$DEST/leftover"
  run gstack_ensure "$DEST" "$VENDOR" "$UPSTREAM"
  [ "$status" -eq 0 ]
  [ -d "$DEST/.git" ]
  [ ! -e "$DEST/leftover" ]
  [ ! -e "$DEST/gstack" ]
  ls -d "$BATS_TEST_TMPDIR/skills/gstack.broken-"* >/dev/null
}

@test "ensure: a real install is left alone" {
  gstack_ensure "$DEST" "$VENDOR" "$UPSTREAM" >/dev/null
  rm "$DEST/.setup-ran"
  run gstack_ensure "$DEST" "$VENDOR" "$UPSTREAM"
  [ "$status" -eq 0 ]
  [ ! -f "$DEST/.setup-ran" ]
  [[ "$output" == *"already installed"* ]]
}

@test "ensure: never leaves a half-cloned directory behind on failure" {
  run gstack_ensure "$DEST" "$VENDOR" "$BATS_TEST_TMPDIR/does-not-exist.git"
  [ ! -d "$DEST/.git" ]
  [ -z "$(ls -d "$BATS_TEST_TMPDIR"/skills/gstack.clone-* 2>/dev/null)" ]
}

@test "ensure: reports an error when both clone and vendor copy are unavailable" {
  run gstack_ensure "$DEST" "$BATS_TEST_TMPDIR/no-vendor" "$BATS_TEST_TMPDIR/does-not-exist.git"
  [ "$status" -ne 0 ]
  [ ! -e "$DEST" ]
  [[ "$output" == *"not installed"* ]]
}
