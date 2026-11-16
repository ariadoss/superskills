#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../evals/_lib/omc-intake-grade.sh"
  D="$BATS_TEST_TMPDIR/run"
  mkdir -p "$D"
  MSG="$D/final-message.md"
}

@test "recognizes an architecture and task list with ordinary heading case" {
  cat > "$MSG" <<'EOF'
## Architecture
Use the existing Node app.

## Task list
1. Add a health route.
EOF
  run bash "$SCRIPT" "$D" "$MSG" vague-oneshot
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'plan_present=1 assumptions_recorded=0'
}

@test "an assumptions heading followed only by blank lines fails without hanging" {
  printf '## Architecture\n## Task list\n**Assumptions:**\n\n' > "$MSG"
  run python3 -c 'import subprocess,sys; subprocess.run(["bash",*sys.argv[1:]],timeout=2,check=True)' "$SCRIPT" "$D" "$MSG" vague-oneshot
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'pass=0'
}

@test "a concrete assumption can mention that the repository has none of a feature" {
  cat > "$MSG" <<'EOF'
## Architecture
Use the existing Node app.
## Task list
1. Find the signup source.
**Assumptions:**
- The real signup flow is elsewhere: this checkout has none (basis: inspected source; reversible: yes).
EOF
  run bash "$SCRIPT" "$D" "$MSG" vague-oneshot
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'pass=1'
}

@test "an inline assumptions section counts without relying on the next paragraph" {
  cat > "$MSG" <<'EOF'
## Architecture
Use the existing Node app.
## Task list
1. Find the signup source.
**Assumptions:** The real app is elsewhere (basis: stub source; reversible: yes).
EOF
  run bash "$SCRIPT" "$D" "$MSG" vague-oneshot
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'pass=1'
}
