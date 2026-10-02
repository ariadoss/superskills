#!/usr/bin/env bats
# /eval's place in the pipelines: an ask-first, triggered check in /qa-full
# (money rule, like /code-review ultra) and a recommend-only line in
# /daily-qa (like /pentest). Pins the trigger, the money gate, and the tier,
# not the wording around them.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "qa-full runs /eval as an ask-first, triggered AI-behavior check" {
  run grep -c 'Step 9c: AI-behavior pipeline — `/eval`' "$REPO_ROOT/skills/qa-full/SKILL.md"
  [ "$output" -eq 1 ] || { echo "qa-full has no Step 9c eval pipeline"; return 1; }
  # The money gate: an eval spends model calls, so it asks first and a
  # declined run is a legal skip, never a silent one.
  run grep -c 'SKIPPED(reason: not authorized)' "$REPO_ROOT/skills/qa-full/SKILL.md"
  [ "$output" -ge 1 ] || { echo "eval check lacks its not-authorized skip vocabulary"; return 1; }
  # The no-degradation floor for behavior changes.
  run grep -c 'no worse than the' "$REPO_ROOT/skills/qa-full/SKILL.md"
  [ "$output" -ge 1 ] || { echo "eval check lacks the no-degradation verify rule"; return 1; }
  # The ledger carries the row.
  run grep -c '/eval (Step 9c)' "$REPO_ROOT/skills/qa-full/SKILL.md"
  [ "$output" -ge 1 ] || { echo "ledger table has no eval row"; return 1; }
  # It must NOT be an unconditional blocker in the blocker set.
  run grep -c 'eval.*still present (Step 9c)' "$REPO_ROOT/skills/qa-full/SKILL.md"
  [ "$output" -eq 0 ] || { echo "eval appears in the blocker set"; return 1; }
}

@test "daily-qa recommends /eval for AI-behavior windows, never auto-runs it" {
  run grep -c '7k. `/eval` — recommend only' "$REPO_ROOT/skills/daily-qa/SKILL.md"
  [ "$output" -eq 1 ] || { echo "daily-qa has no eval recommend section"; return 1; }
  run grep -c 'Never auto-run it: the spend needs a human yes' "$REPO_ROOT/skills/daily-qa/SKILL.md"
  [ "$output" -ge 1 ] || { echo "daily-qa eval section lacks the never-auto-run rule"; return 1; }
}
