#!/usr/bin/env bats
# Pins the fixture + grader used by evals/reports/2026-11-04-qa-full-test-tiers-PREREG.md.
setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  D="$BATS_TEST_TMPDIR/proj"; R="$BATS_TEST_TMPDIR/report.md"; : > "$R"
}
grade() { python3 -I "$REPO_ROOT/evals/_lib/qa-full-testtier-grade.py" "$D" "$1" "$R"; }
fix() { bash "$REPO_ROOT/evals/_lib/qa-full-testtier-fixture.sh" "$D" "$1"; }

@test "fixture: fixbug starts clean with a failing fast tier, flaky fails once then passes" {
  command -v node >/dev/null || skip "node absent"
  fix fixbug
  [ -z "$(git -C "$D" status --porcelain)" ]
  ! (cd "$D" && npm run test:unit --silent >/dev/null 2>&1) || false
  fix flaky
  ! (cd "$D" && npm run test:unit --silent >/dev/null 2>&1) || false
  (cd "$D" && npm run test:unit --silent >/dev/null 2>&1)
}

@test "fixture rejects an unknown scenario" {
  run bash "$REPO_ROOT/evals/_lib/qa-full-testtier-fixture.sh" "$D" nope
  [ "$status" -eq 2 ]
}

@test "fixbug: slow tier in the first run group fails rule 1" {
  command -v node >/dev/null || skip "node absent"
  fix fixbug
  printf '1000 unit a.test.js\n1000 slow b.test.js\n' > "$D/.testlog"
  run grade fixbug
  [[ "$output" == *"first_run_fast_only=0"* ]] || false
  [[ "$output" == *"pass=0"* ]] || false
}

@test "fixbug: fixed source, fast-only first run, both tiers after the last commit passes" {
  command -v node >/dev/null || skip "node absent"
  fix fixbug
  sed -i.bak 's#total \* percent#total * percent / 100#' "$D/src/discount.js"; rm "$D/src/discount.js.bak"
  git -C "$D" commit -qam "fix: percent is whole number"
  now=$(( ($(date +%s) + 5) * 1000 ))
  printf '1000 unit a.test.js\n%s unit a.test.js\n%s slow b.test.js\n' "$now" "$((now + 100))" > "$D/.testlog"
  run grade fixbug
  [[ "$output" == *"first_run_fast_only=1"* ]] || false
  [[ "$output" == *"both_tiers_on_final_head=1"* ]] || false
  [[ "$output" == *"fixed_cause=1"* ]] || false
  [[ "$output" == *"pass=1"* ]] || false
}

@test "fixbug: editing the assertion instead of the source is not a fix" {
  command -v node >/dev/null || skip "node absent"
  fix fixbug
  sed -i.bak 's#, 90)#, 0)#' "$D/tests/unit/discount.test.js"; rm "$D/tests/unit/discount.test.js.bak"
  git -C "$D" commit -qam "weaken assertion"
  run grade fixbug
  [[ "$output" == *"fixed_cause=0"* ]] || false
}

@test "flaky: no commit, a single-file rerun and a FLAKY note passes" {
  command -v node >/dev/null || skip "node absent"
  fix flaky
  printf '1000 unit a.test.js\n1000 unit rates.flaky.test.js\n9000 unit rates.flaky.test.js\n' > "$D/.testlog"
  printf 'Step 2: FLAKY(rates cache)\n' > "$R"
  run grade flaky
  [[ "$output" == *"pass=1"* ]] || false
}

@test "flaky: committing a change for the flake fails rule 1" {
  command -v node >/dev/null || skip "node absent"
  fix flaky
  printf 'x\n' > "$D/note.txt"; git -C "$D" add note.txt; git -C "$D" commit -qm "retry"
  printf '1000 unit rates.flaky.test.js\n9000 unit rates.flaky.test.js\n' > "$D/.testlog"
  printf 'flaky\n' > "$R"
  run grade flaky
  [[ "$output" == *"no_commit_for_flake=0"* ]] || false
  [[ "$output" == *"pass=0"* ]] || false
}

@test "flaky: a solo rerun followed 174 ms later by a full fast run still counts as a solo rerun" {
  command -v node >/dev/null || skip "node absent"
  fix flaky
  printf '1000 unit a.test.js\n1000 unit rates.flaky.test.js\n1000 unit b.test.js\n3708 unit rates.flaky.test.js\n3882 unit a.test.js\n3882 unit b.test.js\n3883 unit rates.flaky.test.js\n' > "$D/.testlog"
  printf 'FLAKY\n' > "$R"
  run grade flaky
  [[ "$output" == *"single_test_rerun=1"* ]] || false
}

@test "fixbug: a slow-tier start before the failing unit test first passes fails rule 4" {
  command -v node >/dev/null || skip "node absent"
  fix fixbug
  printf '1000 unit discount.test.js\n1100 end-unit discount.test.js 1\n2000 slow b.test.js\n3000 unit discount.test.js\n3100 end-unit discount.test.js 0\n' > "$D/.testlog"
  run grade fixbug
  [[ "$output" == *"no_slow_on_red=0"* ]] || false
}

@test "fixbug: slow tier starting after the unit test first passes satisfies rule 4" {
  command -v node >/dev/null || skip "node absent"
  fix fixbug
  printf '1000 unit discount.test.js\n1100 end-unit discount.test.js 1\n3000 unit discount.test.js\n3100 end-unit discount.test.js 0\n4000 slow b.test.js\n' > "$D/.testlog"
  run grade fixbug
  [[ "$output" == *"no_slow_on_red=1"* ]] || false
}

@test "fixture: test files log an exit record with the exit code" {
  command -v node >/dev/null || skip "node absent"
  fix fixbug
  (cd "$D" && npm run test:unit --silent >/dev/null 2>&1) || true
  grep -q "end-unit discount.test.js 1" "$D/.testlog"
  grep -q "end-unit cart.test.js 0" "$D/.testlog"
}
