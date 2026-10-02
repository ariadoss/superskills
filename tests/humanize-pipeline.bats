#!/usr/bin/env bats
# /humanize's place in the pipelines: a file-triggered, warnings-tier check in
# /qa-full (like /web-perf or /pentest: fires only when its files changed) and
# a recommend-only line in /daily-qa. Pins the trigger and the tier, not the
# wording around them.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "qa-full runs /humanize as a triggered, warnings-tier prose check" {
  run grep -c 'Step 9b: Prose quality pipeline — `/humanize`' "$REPO_ROOT/skills/qa-full/SKILL.md"
  [ "$output" -eq 1 ] || { echo "qa-full has no Step 9b humanize pipeline"; return 1; }
  # Markdown-only trigger: prose files, never code comments.
  run grep -c 'Markdown only, never code comments' "$REPO_ROOT/skills/qa-full/SKILL.md"
  [ "$output" -ge 1 ] || { echo "humanize check lacks its md-only boundary"; return 1; }
  # Warnings tier: a surviving flag is never a blocker.
  run grep -c 'never UNFIXED blockers' "$REPO_ROOT/skills/qa-full/SKILL.md"
  [ "$output" -ge 1 ] || { echo "humanize check can block a ship; it must stay warnings-tier"; return 1; }
  # The ledger carries the row, so the no-silent-skips accounting covers it.
  run grep -c '/humanize (Step 9b)' "$REPO_ROOT/skills/qa-full/SKILL.md"
  [ "$output" -ge 1 ] || { echo "ledger table has no humanize row"; return 1; }
  # It must NOT be in the blocker set.
  run grep -c 'humanize.*still present (Step 9b)' "$REPO_ROOT/skills/qa-full/SKILL.md"
  [ "$output" -eq 0 ] || { echo "humanize appears in the blocker set"; return 1; }
}

@test "daily-qa recommends /humanize for prose-drift windows, never auto-runs it" {
  run grep -c '7j. `/humanize` — recommend only' "$REPO_ROOT/skills/daily-qa/SKILL.md"
  [ "$output" -eq 1 ] || { echo "daily-qa has no humanize recommend section"; return 1; }
  run grep -c 'never auto-runs unattended' "$REPO_ROOT/skills/daily-qa/SKILL.md"
  [ "$output" -ge 1 ] || { echo "daily-qa humanize section lacks the no-auto-run rule"; return 1; }
}
