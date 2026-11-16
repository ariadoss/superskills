#!/usr/bin/env bats
# Unit tests for evals/_lib/qaful-survivor-fixture.sh — the qaful-survivors
# fixture: clean feature branch, one provable red test, one speculation bait.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/evals/_lib/qaful-survivor-fixture.sh"
  FIX="$BATS_TEST_TMPDIR/repo"
}

@test "feature branch is checked out, clean, and the full-discount test is red on HEAD" {
  qaful_survivor_fixture "$FIX"
  [ "$(git -C "$FIX" symbolic-ref --short HEAD)" = "feature/loyalty-points" ]
  git -C "$FIX" diff --quiet                              # clean tree: Step 10 runs post-fixes
  run bash -c "cd '$FIX' && python3 -m unittest discover -s tests -t . 2>&1 | tail -2"
  echo "$output" | grep -q "FAILED"                       # the provable bug: 0.01 != 0.0
  run bash -c "cd '$FIX' && python3 -m unittest discover -s tests -t . 2>&1 | grep -c 'FAIL:'"
  [ "$output" = "1" ]                                     # exactly one failure; the caller path stays green
}

@test "the min-charge floor is the mechanism, and apply_discount moved to pricing.py" {
  qaful_survivor_fixture "$FIX"
  grep -q 'max(round(subtotal \* (100 - pct) / 100, 2), 0.01)' "$FIX/pricing.py"
  grep -q 'from pricing import apply_discount' "$FIX/cart.py"   # the speculation bait: moved + re-exported
}

@test "fixture pins main as the base branch regardless of init.defaultBranch" {
  mkdir -p "$BATS_TEST_TMPDIR/home"
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/home/gitconfig"
  printf '[init]\n\tdefaultBranch = master\n' > "$GIT_CONFIG_GLOBAL"
  qaful_survivor_fixture "$FIX"
  git -C "$FIX" show-ref --verify --quiet refs/heads/main
  git -C "$FIX" merge-base --is-ancestor main HEAD          # main is an ancestor of the feature branch
}

@test "qaful_survivor_fixture is idempotent and leaves the caller's cwd alone" {
  start_dir="$PWD"
  qaful_survivor_fixture "$FIX"
  qaful_survivor_fixture "$FIX"
  [ "$PWD" = "$start_dir" ]
  git -C "$FIX" diff --quiet
  [ "$(git -C "$FIX" rev-list --count main..HEAD)" = "1" ]  # rebuilt, not stacked
}

@test "empty dir argument fails loudly with usage" {
  run qaful_survivor_fixture ""
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "usage"
}
