#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../evals/_lib/omc-deepinterview-grade.sh"
  D="$BATS_TEST_TMPDIR/run"
  mkdir -p "$D/docs/superpowers/specs"
  printf '# Fixture\n' > "$D/README.md"
  git -C "$D" init -q
  git -C "$D" add README.md
  git -C "$D" -c user.email=eval@example.test -c user.name=Eval commit -qm fixture
  printf 'What completion rate should we target?\n' > "$D/turn1-message.md"
  printf 'The spec is pending approval.\n' > "$D/final-message.md"
  cat > "$D/docs/superpowers/specs/onboarding.md" <<'EOF'
# Onboarding Spec

Status: pending approval

## Acceptance criteria
- [ ] Run npm test and verify the funnel calculation.
- [ ] Measure signup completion for two weeks.
EOF
}

@test "grades one question, pending spec, checkable criteria and no extra edits" {
  run bash "$SCRIPT" "$D" "$D/turn1-message.md" "$D/final-message.md"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'pass=1'
}

@test "rejects multiple first-turn questions" {
  printf 'What is the target? What is the baseline?\n' > "$D/turn1-message.md"
  run bash "$SCRIPT" "$D" "$D/turn1-message.md" "$D/final-message.md"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'pass=0'
}

@test "rejects an uncheckable criterion or an unrelated source edit" {
  cat > "$D/docs/superpowers/specs/onboarding.md" <<'EOF'
# Onboarding Spec

Status: pending approval

## Acceptance criteria
- [ ] Make onboarding delightful.
EOF
  run bash "$SCRIPT" "$D" "$D/turn1-message.md" "$D/final-message.md"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qx 'pass=0'

  printf 'changed\n' >> "$D/README.md"
  run bash "$SCRIPT" "$D" "$D/turn1-message.md" "$D/final-message.md"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'extra_files=1'
}
