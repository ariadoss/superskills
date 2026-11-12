#!/usr/bin/env bats
# /qa-full is a short core plus steps/ files. The core must survive the host's
# post-compaction truncation (about 20,694 characters), so it stays well below that.
setup() {
  Q="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/skills/qa-full"
}

@test "core SKILL.md stays at or under 18000 bytes" {
  [ "$(wc -c < "$Q/SKILL.md" | tr -d ' ')" -le 18000 ] || false
}

@test "the core names every step file and each one exists" {
  for f in "$Q"/steps/*.md; do
    b="$(basename "$f")"
    grep -qF "steps/$b" "$Q/SKILL.md" || { echo "core does not name steps/$b"; return 1; }
  done
  [ "$(ls "$Q"/steps/*.md | wc -l | tr -d ' ')" -ge 14 ] || false
}

@test "every step heading in the core is followed by a Read instruction" {
  n_head="$(grep -c '^## Step [0-9]' "$Q/SKILL.md")"
  n_read="$(grep -c 'follow it in full' "$Q/SKILL.md")"
  [ "$n_head" -ge 12 ] || false
  [ "$n_read" -ge "$n_head" ] || false
}

@test "the core tells a resumed run to re-read itself and keep going to Step 10" {
  grep -qF 'If your context was compacted' "$Q/SKILL.md"
  grep -qF 'keep going to Step 10' "$Q/SKILL.md"
}

@test "the hard rules stay in the core" {
  grep -q '^## Hard rules' "$Q/SKILL.md"
  grep -qF 'Run to completion' "$Q/SKILL.md"
}
