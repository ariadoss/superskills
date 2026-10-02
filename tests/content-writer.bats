#!/usr/bin/env bats
# /content-writer's contract with the rest of the core pack: its workflow ends
# in a /humanize pass, so drafts leave without AI tells. Pins the reference
# and the phase shape, not the wording around them.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "content-writer's workflow ends with a /humanize pass" {
  run grep -c 'Phase 5' "$REPO_ROOT/skills/content-writer/SKILL.md"
  [ "$output" -ge 1 ] || { echo "content-writer has no Phase 5"; return 1; }
  run grep -c '/humanize' "$REPO_ROOT/skills/content-writer/SKILL.md"
  [ "$output" -ge 1 ] || { echo "content-writer does not reference /humanize"; return 1; }
  # The reference must sit in the post-review phase, not in research/outline.
  run grep -A2 '^### Phase 5' "$REPO_ROOT/skills/content-writer/SKILL.md"
  [[ "$output" == *'/humanize'* ]] || { echo "Phase 5 does not invoke /humanize"; return 1; }
}

@test "the humanize skill ships alongside content-writer (both core)" {
  [ -f "$REPO_ROOT/skills/humanize/SKILL.md" ] || false
  [ -f "$REPO_ROOT/skills/content-writer/SKILL.md" ] || false
}
