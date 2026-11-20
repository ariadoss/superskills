#!/usr/bin/env bats
# Tests for scripts/lib/suite-stamp-lib.sh and scripts/suite-stamp.sh.
# Hermetic: a throwaway git repo under BATS_TEST_TMPDIR.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CLI="$REPO_ROOT/scripts/suite-stamp.sh"
  R="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$R" && cd "$R"
  git init -q -b main
  git config user.email t@t && git config user.name t
  echo one > a.txt && git add a.txt && git commit -qm one
  COUNT="$BATS_TEST_TMPDIR/count"
  : > "$COUNT"
}

# A suite command that records each real run.
init_counting() { "$CLI" init "echo x >> '$COUNT'"; }
runs() { wc -l < "$COUNT" | tr -d ' '; }

@test "lib: ssl_tree returns the tree hash of a ref" {
  source "$REPO_ROOT/scripts/lib/suite-stamp-lib.sh"
  [ "$(ssl_tree HEAD)" = "$(git rev-parse 'HEAD^{tree}')" ] || false
}

@test "lib: ssl_has is false before and true after ssl_record" {
  source "$REPO_ROOT/scripts/lib/suite-stamp-lib.sh"
  git config --local superskills.suiteCommand "make test"
  t="$(ssl_tree HEAD)"
  run ssl_has "$t"; [ "$status" -ne 0 ] || false
  ssl_record "$t" "make test"
  run ssl_has "$t"; [ "$status" -eq 0 ] || false
}

@test "lib: ssl_has is false when no suite command is configured, even for an empty-command stamp" {
  source "$REPO_ROOT/scripts/lib/suite-stamp-lib.sh"
  t="$(ssl_tree HEAD)"
  ssl_record "$t" ""
  run ssl_has "$t"; [ "$status" -ne 0 ] || false
}

@test "check and ensure fail cleanly without init" {
  run "$CLI" check
  [ "$status" -ne 0 ] || false
  run "$CLI" ensure
  [ "$status" -ne 0 ] || false
  [ ! -s "$(git rev-parse --git-common-dir)/suite-stamps" ] || false
}

@test "run: refuses without an init'd command" {
  run "$CLI" run
  [ "$status" -ne 0 ] || false
  [[ "$output" == *"init"* ]] || false
}

@test "run: refuses a dirty tree, because the stamp would describe code that was not tested" {
  init_counting
  echo dirty >> a.txt
  run "$CLI" run
  [ "$status" -ne 0 ] || false
  [ "$(runs)" = 0 ] || false
}

@test "run: a passing suite stamps the tree" {
  init_counting
  run "$CLI" run
  [ "$status" -eq 0 ] || false
  run "$CLI" check
  [ "$status" -eq 0 ] || false
}

@test "run: a failing re-run revokes an earlier pass of the same tree" {
  git config --local superskills.suiteCommand true
  "$CLI" run
  git config --local superskills.suiteCommand false
  run "$CLI" run
  [ "$status" -ne 0 ] || false
  git config --local superskills.suiteCommand true
  run "$CLI" check
  [ "$status" -ne 0 ] || false
}

@test "run: a suite that rewrites a tracked file is not stamped" {
  git config --local superskills.suiteCommand "echo changed >> a.txt"
  run "$CLI" run
  [ "$status" -ne 0 ] || false
  run "$CLI" check
  [ "$status" -ne 0 ] || false
}

@test "run: a failing suite does not stamp and returns its status" {
  "$CLI" init "exit 3"
  run "$CLI" run
  [ "$status" -eq 3 ] || false
  run "$CLI" check
  [ "$status" -eq 1 ] || false
}

@test "ensure: second call on the same tree does not re-run the suite" {
  init_counting
  "$CLI" ensure; "$CLI" ensure
  [ "$(runs)" = 1 ] || false
}

@test "fast-forward to main reuses the branch's stamp" {
  init_counting
  git checkout -q -b feat
  echo two > b.txt && git add b.txt && git commit -qm two
  "$CLI" ensure
  git checkout -q main && git merge -q --ff-only feat
  "$CLI" ensure
  [ "$(runs)" = 1 ] || false
}

@test "merge commit that brought in new work from main re-runs the suite" {
  init_counting
  git checkout -q -b feat
  echo two > b.txt && git add b.txt && git commit -qm two
  "$CLI" ensure
  git checkout -q main
  echo three > c.txt && git add c.txt && git commit -qm three
  git merge -q --no-ff feat -m merge
  "$CLI" ensure
  [ "$(runs)" = 2 ] || false
}

@test "squash of identical code reuses the stamp" {
  init_counting
  git checkout -q -b feat
  echo two > b.txt && git add b.txt && git commit -qm two
  "$CLI" ensure
  git checkout -q main && git merge -q --squash feat && git commit -qm squashed
  "$CLI" ensure
  [ "$(runs)" = 1 ] || false
}

@test "run then check: a suite command containing a backslash is compared literally" {
  git config --local superskills.suiteCommand "printf '%s\\n' ok"
  run "$CLI" run </dev/null
  [ "$status" -eq 0 ] || false
  run "$CLI" check </dev/null
  [ "$status" -eq 0 ] || false
}

@test "run then check: a suite command with quotes and a dollar sign is compared literally" {
  git config --local superskills.suiteCommand "echo \"a\$HOME\" 'b'"
  run "$CLI" run </dev/null
  [ "$status" -eq 0 ] || false
  run "$CLI" check </dev/null
  [ "$status" -eq 0 ] || false
}
