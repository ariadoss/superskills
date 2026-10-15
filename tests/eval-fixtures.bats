#!/usr/bin/env bats
# eval-fixtures — the three claw-continuity instruments' fixtures build
# hermetically and self-verify. Pinned mechanically because a fixture
# regression is an eval-instrument defect (the 2026-10-15 shipping([11])
# one-item-not-eleven bug was caught by a manual smoke only); these tests
# make that class impossible to reintroduce silently.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WORK="$BATS_TEST_TMPDIR/fixture-work"
  mkdir -p "$WORK"
}

@test "handoff-rewrite fixture builds with a passing test suite and an untracked note" {
  cd "$WORK" || exit 1
  bash "$REPO_ROOT/evals/handoff-rewrite/fixture.sh"
  cd fixture-repo || exit 1
  run python3 tests/test_calc.py
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"flat ok"* ]] || false
  [[ "$output" == *"express ok"* ]] || false
  # two commits, the handoff note untracked (the skill's own contract), and
  # the unstaged half-work present — the premise the graders grade against.
  # Capture-form assertions: a bare `cmd && false` mid-test is a no-op under
  # bats' last-line rule (tests/bats-assertions.bats owns this contract).
  [ "$(git rev-parse HEAD~1)" != "$(git rev-parse HEAD)" ] || false
  out="$(git ls-files --error-unmatch handoff-7c1d2f.md 2>/dev/null)" || true
  [ -z "$out" ] || false
  out="$(git ls-files --error-unmatch src/rates.py 2>/dev/null)" || true
  [ -z "$out" ] || false
  [ -f src/rates.py ] || false
}

@test "verify-todolist fixture builds with a passing test suite" {
  cd "$WORK" || exit 1
  bash "$REPO_ROOT/evals/verify-todolist/fixture.sh"
  run python3 fixture-repo/tests/test_labels.py
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"labels ok"* ]] || false
}

@test "quota-resume-direct fixture builds the committed salvage state" {
  cd "$WORK" || exit 1
  bash "$REPO_ROOT/evals/quota-resume-direct/fixture.sh"
  [ -f fixture-repo/QUOTA-RESUME.md ] || false
  out="$(git -C fixture-repo status --porcelain)" || true
  [ -z "$out" ] || false
}
