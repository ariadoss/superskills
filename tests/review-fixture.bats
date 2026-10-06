#!/usr/bin/env bats
# Unit tests for evals/_lib/review-fixture.sh — the two-mode review fixture
# behind the review-calibration / review-clean eval cases.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/evals/_lib/review-fixture.sh"
  FIX="$BATS_TEST_TMPDIR/repo"
}

@test "bait mode plants the introduced bug, keeps the pre-existing bug, adds the retry bait" {
  review_fixture "$FIX" bait
  [ -f "$FIX/app.py" ]
  grep -q 'int(total \* 100) / 1000' "$FIX/app.py"      # the introduced ten-fold undercharge
  grep -q 'range(1, int(raw))' "$FIX/app.py"            # the untouched pre-existing off-by-one
  grep -q 'attempts=3' "$FIX/app.py"                    # the speculative-risk retry loop
  git -C "$FIX" diff --quiet && return 1 || true        # an uncommitted diff must exist
}

@test "benign mode changes no behavior" {
  review_fixture "$FIX" benign
  grep -q 'value = charge(total)' "$FIX/app.py"         # pure style: intermediate local
  if grep -q '/ 1000' "$FIX/app.py"; then return 1; fi  # no introduced bug
}

@test "review_fixture is idempotent and leaves the caller's cwd alone" {
  start_dir="$PWD"
  review_fixture "$FIX" bait
  review_fixture "$FIX" bait                            # second scaffold in the same shell
  [ "$PWD" = "$start_dir" ]                             # subshell isolation held
  grep -q '/ 1000' "$FIX/app.py"
  git -C "$FIX" rev-parse HEAD >/dev/null
}

@test "unknown mode fails loudly" {
  run review_fixture "$FIX" nope
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "unknown mode"
}
