#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../evals/_lib/omc-sdd-grade.sh"
  D="$BATS_TEST_TMPDIR/run"
  WS="$D/.superpowers/sdd/fixture-plan"
  mkdir -p "$WS"
  : > "$D/final-message.md"
}

@test "dispatch grader reads the dispatch file when the task brief also exists" {
  : > "$WS/task-2-brief.md"
  cat > "$WS/task-2-dispatch.md" <<'EOF'
Read task-1-handoff.md for prior decisions.
Write an Assumptions section in task-2-report.md.
EOF

  run bash "$SCRIPT" "$D" "$D/final-message.md" dispatch
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'pass=1'
}
