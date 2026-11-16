#!/usr/bin/env bats
# feedback-baseline: record a plan workspace's pre-existing test failures once,
# then gate later runs on failure-signature deltas (NEW failures block; baseline
# failures are warnings; GONE failures are fixes). Re-baselining requires a reason.
#
# Note: bats' `run` runs in a subshell, so ids are always fed via --from files
# (one stdin-path test uses bash -c to keep the pipe inside the run).
setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../skills/subagent-driven-development/scripts/feedback-baseline.sh"
  WS="$BATS_TEST_TMPDIR/ws"
  mkdir -p "$WS"
}

ids() { # write each argument as an id file, print its path
  F="$BATS_TEST_TMPDIR/ids-$RANDOM$$"
  : > "$F"
  for id in "$@"; do printf '%s\n' "$id" >> "$F"; done
  printf '%s' "$F"
}

@test "record then check: new failures FAIL, gone failures noted, baseline passes" {
  bash "$SCRIPT" record --workspace "$WS" --from "$(ids tests/a.py::test_one tests/a.py::test_two)"
  [ -f "$WS/feedback-baseline.tsv" ]
  run bash "$SCRIPT" check --workspace "$WS" --from "$(ids tests/a.py::test_one tests/c.py::test_new)"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qx 'NEW tests/c.py::test_new'
  echo "$output" | grep -qx 'GONE tests/a.py::test_two'
  echo "$output" | grep -qx 'BASELINE tests/a.py::test_one'
  echo "$output" | grep -q 'RESULT: FAIL'
}

@test "check passes when every current failure is in the baseline" {
  bash "$SCRIPT" record --workspace "$WS" --from "$(ids a b)"
  run bash "$SCRIPT" check --workspace "$WS" --from "$(ids a b)"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'RESULT: PASS'
  ! echo "$output" | grep -q '^NEW '
}

@test "check passes with fewer failures than the baseline (fixes are not blockers)" {
  bash "$SCRIPT" record --workspace "$WS" --from "$(ids a b)"
  run bash "$SCRIPT" check --workspace "$WS" --from "$(ids a)"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'GONE b'
}

@test "check passes with zero current failures against a non-empty baseline" {
  bash "$SCRIPT" record --workspace "$WS" --from "$(ids a b)"
  run bash "$SCRIPT" check --workspace "$WS" --from "$(ids )"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'RESULT: PASS'
}

@test "input is normalized: blanks and duplicates collapse, ids sort" {
  MESSY="$BATS_TEST_TMPDIR/messy.txt"
  printf '\nx\nx\na\n\n' > "$MESSY"
  bash "$SCRIPT" record --workspace "$WS" --from "$MESSY"
  [ "$(grep -c '^[^#]' "$WS/feedback-baseline.tsv")" -eq 2 ]
  run bash "$SCRIPT" check --workspace "$WS" --from "$(ids a x)"
  [ "$status" -eq 0 ]
}

@test "stdin works as the id source when piped inside the run" {
  run bash -c "printf 'a\n' | '$SCRIPT' record --workspace '$WS'"
  [ "$status" -eq 0 ]
  run bash -c "printf 'a\n' | '$SCRIPT' check --workspace '$WS'"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'BASELINE a'
}

@test "re-recording an existing baseline is refused without --force" {
  bash "$SCRIPT" record --workspace "$WS" --from "$(ids a)"
  run bash "$SCRIPT" record --workspace "$WS" --from "$(ids b)"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi 'already exists'
}

@test "--force without --reason is refused; with --reason it overwrites and logs why" {
  bash "$SCRIPT" record --workspace "$WS" --from "$(ids a)"
  run bash "$SCRIPT" record --workspace "$WS" --from "$(ids b)" --force
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi 'reason'
  bash "$SCRIPT" record --workspace "$WS" --from "$(ids b)" --force --reason "baseline ids went stale after migration"
  grep -qi 'migration' "$WS/feedback-baseline.tsv"
  run bash "$SCRIPT" check --workspace "$WS" --from "$(ids b)"
  [ "$status" -eq 0 ]
}

@test "recording an empty failure set is refused — a green repo needs no baseline" {
  run bash "$SCRIPT" record --workspace "$WS" --from /dev/null
  [ "$status" -ne 0 ]
  [ ! -f "$WS/feedback-baseline.tsv" ]
}

@test "check without a baseline reports it and passes (baseline is optional)" {
  run bash "$SCRIPT" check --workspace "$WS" --from "$(ids a)"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi 'no baseline'
}

@test "a missing workspace or input file is an error, not a silent pass" {
  run bash "$SCRIPT" record --workspace "$BATS_TEST_TMPDIR/nosuch" --from /dev/null
  [ "$status" -eq 2 ]
  bash "$SCRIPT" record --workspace "$WS" --from "$(ids a)"
  run bash "$SCRIPT" check --workspace "$WS" --from "$BATS_TEST_TMPDIR/nosuch.txt"
  [ "$status" -eq 2 ]
}

@test "the baseline carries a version and timestamp header" {
  bash "$SCRIPT" record --workspace "$WS" --from "$(ids a)"
  head -1 "$WS/feedback-baseline.tsv" | grep -q '^# feedback-baseline v1 recorded='
}
