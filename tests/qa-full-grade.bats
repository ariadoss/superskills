#!/usr/bin/env bats
setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  D="$BATS_TEST_TMPDIR/proj"; mkdir -p "$D"
  T="$BATS_TEST_TMPDIR/t.jsonl"
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"a","name":"Skill","input":{"skill":"superskills:defense"}},{"type":"tool_use","id":"b","name":"Skill","input":{"skill":"clean-code"}}]}}' > "$T"
}

@test "lists invoked skills, reports no ledger when none was written" {
  run bash "$REPO_ROOT/evals/_lib/qa-full-grade.sh" "$D" "$T"
  [ "$status" -eq 0 ]
  [[ "$output" == *"invoked=clean-code,defense"* ]]
  [[ "$output" == *"unbacked=n/a"* ]]
}

@test "outcomes: secret_absent and tests_green reflect the fixture repo" {
  printf 'clean\n' > "$D/a.txt"
  run bash "$REPO_ROOT/evals/_lib/qa-full-grade.sh" "$D" "$T"
  [[ "$output" == *"secret_absent=1"* ]]
  printf 'sk_live_FakeFixtureKeyDoNotUse\n' > "$D/b.txt"
  run bash "$REPO_ROOT/evals/_lib/qa-full-grade.sh" "$D" "$T"
  [[ "$output" == *"secret_absent=0"* ]]
}
