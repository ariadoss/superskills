#!/usr/bin/env bats
# /humanize's place in the pipelines: a file-triggered, warnings-tier check in
# /qa-full (like /web-perf or /pentest: fires only when its files changed) and
# a recommend-only line in /daily-qa. Pins the trigger and the tier, not the
# wording around them.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  QF_ALL="$BATS_TEST_TMPDIR/qa-full-all.md"
  cat "$REPO_ROOT/skills/qa-full/SKILL.md" "$REPO_ROOT"/skills/qa-full/steps/*.md > "$QF_ALL"
}

@test "qa-full runs /humanize as a triggered, warnings-tier prose check" {
  run grep -c 'Step 9b: Prose quality pipeline — `/humanize`' "$REPO_ROOT/skills/qa-full/SKILL.md"
  [ "$output" -eq 1 ] || { echo "qa-full has no Step 9b humanize pipeline"; return 1; }
  # Content-based trigger: any user-facing copy by the toolkit's classifier,
  # never code, comments, or prompts.
  run grep -c 'userfacing.py classify' "$QF_ALL"
  [ "$output" -ge 1 ] || { echo "humanize check does not delegate scope to userfacing.py"; return 1; }
  # Warnings tier: a surviving flag is never a blocker.
  run grep -c 'never UNFIXED blockers' "$QF_ALL"
  [ "$output" -ge 1 ] || { echo "humanize check can block a ship; it must stay warnings-tier"; return 1; }
  # The ledger carries the row, so the no-silent-skips accounting covers it.
  run grep -c '/humanize (Step 9b)' "$QF_ALL"
  [ "$output" -ge 1 ] || { echo "ledger table has no humanize row"; return 1; }
  # It must NOT be in the blocker set.
  run grep -c 'humanize.*still present (Step 9b)' "$QF_ALL"
  [ "$output" -eq 0 ] || { echo "humanize appears in the blocker set"; return 1; }
}

@test "daily-qa recommends /humanize for prose-drift windows, never auto-runs it" {
  run grep -c '7j. `/humanize` — recommend only' "$REPO_ROOT/skills/daily-qa/SKILL.md"
  [ "$output" -eq 1 ] || { echo "daily-qa has no humanize recommend section"; return 1; }
  run grep -c 'never auto-runs unattended' "$REPO_ROOT/skills/daily-qa/SKILL.md"
  [ "$output" -ge 1 ] || { echo "daily-qa humanize section lacks the no-auto-run rule"; return 1; }
}

@test "humanize instructions keep internal prompts and comments out of scope" {
  run grep -F 'Internal prompts, agent instructions, plans, and code comments are out of scope' "$REPO_ROOT/skills/humanize/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -F 'Internal prompts, agent instructions, plans, and code comments are out of scope' "$QF_ALL"
  [ "$status" -eq 0 ]
  run grep -F 'Internal prompts, agent instructions, plans, and code comments are out of scope' "$REPO_ROOT/skills/daily-qa/SKILL.md"
  [ "$status" -eq 0 ]
}
