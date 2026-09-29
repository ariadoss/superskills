#!/usr/bin/env bash
# Unit tests for evals/_lib/quota-fixture.sh — the shared scaffold of the
# quota-* eval cases. A drift here silently changes what every quota grader
# measures (the same rationale as tests/doctor-fixture.bats). Each mode gets
# its own workspace: the fixture is not re-runnable in place (the second
# git commit would no-op under set -e).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  command -v python3 >/dev/null 2>&1 || skip "python3 not installed"
}

@test "quota stop fixture: dirty tree on the default branch, failing express test, no resume note" {
  W="$BATS_TEST_TMPDIR/stop"; mkdir -p "$W"
  ( cd "$W" && . "$REPO_ROOT/evals/_lib/quota-fixture.sh" && quota_fixture stop )
  [ "$(git -C "$W/fixture-repo" log --oneline | wc -l | tr -d ' ')" = "1" ] || false
  [ -n "$(git -C "$W/fixture-repo" status --porcelain)" ] || false
  [ ! -f "$W/fixture-repo/QUOTA-RESUME.md" ] || false
  run bash -c "cd '$W/fixture-repo' && python3 tests/test_shipping.py"
  [ "$status" -ne 0 ] || false
  [[ "${lines[0]}" == "flat ok" ]] || false
}

@test "quota resume fixture: clean feature/express, committed resume note, work unfinished" {
  W="$BATS_TEST_TMPDIR/resume"; mkdir -p "$W"
  ( cd "$W" && . "$REPO_ROOT/evals/_lib/quota-fixture.sh" && quota_fixture resume )
  [ "$(git -C "$W/fixture-repo" branch --show-current)" = "feature/express" ] || false
  [ -z "$(git -C "$W/fixture-repo" status --porcelain)" ] || false
  [ "$(git -C "$W/fixture-repo" log --oneline | wc -l | tr -d ' ')" = "2" ] || false
  grep -q "8.00 surcharge" "$W/fixture-repo/QUOTA-RESUME.md" || false
  run bash -c "cd '$W/fixture-repo' && python3 tests/test_shipping.py"
  [ "$status" -ne 0 ] || false
}
