#!/usr/bin/env bats
# gstack 1.97 stopped registering /plan-eng-review, so superskills ships it.
# It must be the full review method, not a pointer: /autoplan loads its Phase 3
# methodology from any skill named plan-eng-review and fails on a short wrapper
# ("Inline methodology is missing its complete review section").

SKILL="$BATS_TEST_DIRNAME/../skills/plan-eng-review/SKILL.md"

@test "plan-eng-review is the full review method, not a pointer" {
  [ "$(wc -l < "$SKILL")" -gt 300 ]
  grep -q 'sections/review-sections.md' "$SKILL"
}

@test "plan-eng-review is in the coding pack and records its upstream" {
  grep -q '^name: plan-eng-review$' "$SKILL"
  grep -q 'upstream: https://github.com/garrytan/gstack' "$SKILL"
  source "$BATS_TEST_DIRNAME/../scripts/lib/skills-lib.sh"
  [[ " $PACK_CODING_REPO " == *" plan-eng-review "* ]] || false
}
