#!/usr/bin/env bats
# export-handoff.sh — the standalone-repo export self-verifies.

setup() {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  OUT="$BATS_TEST_TMPDIR/handoff-out"
}

teardown() {
  # An interrupted run must not leave scratch in the real source tree.
  rm -f "$REPO_ROOT/skills/handoff/SCRATCH.md"
}

@test "exports the skill, relocates session-ref, ships hook/README/LICENSE/NOTICE, passes its own bats" {
  run bash "$REPO_ROOT/scripts/export-handoff.sh" "$OUT"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "tests pass in the exported tree"
  [ -f "$OUT/SKILL.md" ]
  [ -x "$OUT/scripts/session-ref.sh" ]
  [ -x "$OUT/hooks/handoff-trigger-hook.sh" ]
  [ -f "$OUT/README.md" ]
  [ -f "$OUT/LICENSE" ]
  [ -f "$OUT/NOTICE.md" ]
}

@test "an untracked file inside the skill dir does not ship" {
  echo "scratch" > "$REPO_ROOT/skills/handoff/SCRATCH.md"
  run bash "$REPO_ROOT/scripts/export-handoff.sh" "$OUT"
  rm -f "$REPO_ROOT/skills/handoff/SCRATCH.md"
  [ "$status" -eq 0 ]   # bats' own $status — never shadow it with $?
  [ ! -f "$OUT/SCRATCH.md" ]
}
