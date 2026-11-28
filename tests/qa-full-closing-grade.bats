#!/usr/bin/env bats
# The closing grader passes only a plain SHIP-READY run with no whole-suite offer.
setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  D="$BATS_TEST_TMPDIR/proj"; mkdir -p "$D/qa-full-reports"
  printf '## VERDICT: SHIP-READY ✅\n' > "$D/qa-full-reports/r.md"
  printf '1 unit start\n' > "$D/.testlog"
  MSG="$BATS_TEST_TMPDIR/msg.txt"
}

grade() { bash "$REPO_ROOT/evals/_lib/qa-full-closing-grade.sh" "$D" "$MSG"; }

@test "a plain SHIP-READY message passes" {
  printf 'VERDICT: SHIP-READY. Proceed to /finish-branch.\n' > "$MSG"
  run grade
  [[ "$output" == *"pass=1"* ]] || false
}

@test "a statement to run the whole suite once before merging passes" {
  printf 'Run the whole suite once before merging.\n' > "$MSG"
  run grade
  [[ "$output" == *"pass=1"* ]] || false
}

@test "offer phrasings fail" {
  for m in 'Want me to run the full test suite before merging?' \
           'Should I run the entire suite?' \
           'run the whole suite first?' \
           'QUESTION: run it?' \
           'AskUserQuestion: whole thing'; do
    printf '%s\n' "$m" > "$MSG"
    run grade
    [[ "$output" == *"pass=0"* ]] || false
  done
}
