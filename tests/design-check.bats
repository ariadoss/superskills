#!/usr/bin/env bats
# scripts/design-check.py: deterministic binary scorer for the design-pack eval.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  SCRIPT="$REPO_ROOT/scripts/design-check.py"
}

@test "the flawed fixture scores low and names failed checks" {
  run python3 "$SCRIPT" "$REPO_ROOT/evals/design-pack/fixture.html"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1/12" ] || false
  echo "$output" | grep -q "FAIL no-emoji"
}

@test "--json is parseable and reports the same totals" {
  run python3 "$SCRIPT" "$REPO_ROOT/evals/design-pack/fixture.html" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["total"]==12 and d["passed"]==sum(d["checks"].values())'
}

@test "--build adds exactly one applicable check" {
  run python3 "$SCRIPT" "$REPO_ROOT/evals/design-pack/fixture.html" --build --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; assert json.load(sys.stdin)["total"]==13'
}

@test "the same file scores the same twice" {
  a="$(python3 "$SCRIPT" "$REPO_ROOT/evals/design-pack/fixture2.html")"
  b="$(python3 "$SCRIPT" "$REPO_ROOT/evals/design-pack/fixture2.html")"
  [ "$a" = "$b" ]
}

@test "no argument prints usage and exits 2" {
  run python3 "$SCRIPT"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "usage"
}

@test "a missing file fails with a message, not a traceback" {
  run python3 "$SCRIPT" "$BATS_TEST_TMPDIR/nope.html"
  [ "$status" -eq 2 ]
  run grep -c Traceback <<<"$output"
  [ "$output" = "0" ] || false
}
