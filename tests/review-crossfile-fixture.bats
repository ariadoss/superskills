#!/usr/bin/env bats
# Unit tests for evals/_lib/review-crossfile-fixture.sh — the review-crossfile
# fixture: a genuine cross-module break left pending for the review to keep.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/evals/_lib/review-crossfile-fixture.sh"
  FIX="$BATS_TEST_TMPDIR/repo"
}

@test "pending warehouse.py change breaks the orders caller test" {
  review_crossfile_fixture "$FIX"
  [ "$(git -C "$FIX" status --porcelain | wc -l | tr -d ' ')" = "1" ]   # exactly one pending file
  git -C "$FIX" status --porcelain | grep -q "warehouse.py"
  run bash -c "cd '$FIX' && python3 -m unittest discover -s tests -t . 2>&1 | tail -1"
  echo "$output" | grep -q "FAILED"                                     # the caller's test is red
}

@test "stashing the pending change turns the suite green" {
  review_crossfile_fixture "$FIX"
  git -C "$FIX" stash -q
  run bash -c "cd '$FIX' && python3 -m unittest discover -s tests -t . 2>&1 | tail -1"
  echo "$output" | grep -q "OK"                                         # the break is the diff's, not the base's
}

@test "fixture pins main regardless of the machine's init.defaultBranch" {
  mkdir -p "$BATS_TEST_TMPDIR/home"
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/home/gitconfig"
  printf '[init]\n\tdefaultBranch = master\n' > "$GIT_CONFIG_GLOBAL"
  review_crossfile_fixture "$FIX"
  [ "$(git -C "$FIX" symbolic-ref --short HEAD)" = "main" ]
}

@test "review_crossfile_fixture is idempotent and leaves the caller's cwd alone" {
  start_dir="$PWD"
  review_crossfile_fixture "$FIX"
  review_crossfile_fixture "$FIX"
  [ "$PWD" = "$start_dir" ]
  [ "$(git -C "$FIX" status --porcelain | wc -l | tr -d ' ')" = "1" ]   # rebuilt, not appended
}

@test "empty dir argument fails loudly with usage" {
  run review_crossfile_fixture ""
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "usage"
}
