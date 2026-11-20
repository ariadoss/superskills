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
