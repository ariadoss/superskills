#!/usr/bin/env bats
# /daily-qa must not silently skip a triggered step. Pins: /qa-only auto-runs on
# frontend changes, /db-optimize stays auto-run on migrations, every §7 step lands in a
# ledger, and the drift script is resolved from the superskills install, not the repo.

setup() {
  SKILL="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/skills/daily-qa/SKILL.md"
}

@test "frontend changes auto-run the browser pass (report-only), never just a recommendation" {
  run grep -c '^### 7d. `/qa` — auto-run if frontend changed' "$SKILL"
  [ "$output" -eq 1 ]
  run grep -c 'invoke `/qa-only`' "$SKILL"
  [ "$output" -ge 1 ]
  run grep -c '7d. `/qa` — recommend only' "$SKILL"
  [ "$output" -eq 0 ]
}

@test "an unreachable app is a recorded skip, not a silent one" {
  run grep -F 'skipped: app not reachable' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "db-optimize still auto-runs on migrations" {
  run grep -c '^### 7a. `/db-optimize` — auto-run if triggered' "$SKILL"
  [ "$output" -eq 1 ]
  run grep -F '`**/migrations/**`' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "the section 7 ledger is mandatory and nothing skips silently" {
  run grep -c '^### 7z. The §7 ledger (mandatory)' "$SKILL"
  [ "$output" -eq 1 ]
  run grep -c "skip silently (don't even mention it)\|If no infra files changed, skip silently" "$SKILL"
  [ "$output" -eq 0 ]
  run grep -F '## 6. §7 ledger' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "the drift script is resolved from the superskills install, with a recorded skip if absent" {
  run grep -F 'SUPERSKILLS_DIR' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F '~/Sites/superskills' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F 'skipped: drift script not found' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "db and ui triggers are decided by the shared qa-triggers.sh helper in both skills" {
  QF="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/skills/qa-full/SKILL.md"
  for f in "$SKILL" "$QF"; do
    run grep -c 'qa-triggers.sh" db' "$f"
    [ "$output" -ge 1 ]
    run grep -c 'qa-triggers.sh" ui' "$f"
    [ "$output" -ge 1 ]
  done
}
