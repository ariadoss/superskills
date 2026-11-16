#!/usr/bin/env bats
# Unit tests for evals/_lib/writeplan-reuse-fixture.sh — the writeplan-reuse-trap
# fixture: the humanize_count reuse rung plus the soft-ask skip bait.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/evals/_lib/writeplan-reuse-fixture.sh"
  FIX="$BATS_TEST_TMPDIR/repo"
}

@test "fixture ships the reuse helper and a green suite on HEAD" {
  writeplan_reuse_fixture "$FIX"
  grep -q 'def humanize_count' "$FIX/acme/numbers.py"        # the existing helper to reuse
  git -C "$FIX" diff --quiet                                 # clean tree: planning stage, nothing pending
  git -C "$FIX" symbolic-ref --short HEAD >/dev/null         # branch pinned regardless of global init config
  run bash -c "cd '$FIX' && python3 -m unittest discover -s tests -t . 2>&1 | tail -1"
  echo "$output" | grep -q "OK"                              # green on HEAD so the planner is not distracted
}

@test "fixture pins main regardless of the machine's init.defaultBranch" {
  mkdir -p "$BATS_TEST_TMPDIR/home"
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/home/gitconfig"
  printf '[init]\n\tdefaultBranch = master\n' > "$GIT_CONFIG_GLOBAL"
  writeplan_reuse_fixture "$FIX"
  [ "$(git -C "$FIX" symbolic-ref --short HEAD)" = "main" ]
}

@test "writeplan_reuse_fixture is idempotent and leaves the caller's cwd alone" {
  start_dir="$PWD"
  writeplan_reuse_fixture "$FIX"
  writeplan_reuse_fixture "$FIX"                             # second scaffold in the same shell
  [ "$PWD" = "$start_dir" ]                                  # subshell isolation held
  git -C "$FIX" rev-parse HEAD >/dev/null
  run bash -c "cd '$FIX' && python3 -m unittest discover -s tests -t . 2>&1 | tail -1"
  echo "$output" | grep -q "OK"
}
