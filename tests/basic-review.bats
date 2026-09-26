#!/usr/bin/env bats
# /basic-review ships gstack's review checklist so it works without gstack
# installed. The copy must match the vendored snapshot exactly, or the skill
# silently reviews against a stale list. scripts/sync-gstack.sh refreshes both.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "the basic-review checklist is the vendored gstack checklist, verbatim" {
  body="$(sed '1,/^-->$/d' "$REPO_ROOT/skills/basic-review/checklist.md" | sed '1{/^$/d;}')"
  [ "$body" = "$(cat "$REPO_ROOT/vendor/gstack/review/checklist.md")" ] || { echo "drifted: re-run scripts/sync-gstack.sh"; return 1; }
}

@test "the checklist names its gstack version and license" {
  head -3 "$REPO_ROOT/skills/basic-review/checklist.md" | grep -q "gstack $(cat "$REPO_ROOT/vendor/gstack/VERSION")" || false
  head -3 "$REPO_ROOT/skills/basic-review/checklist.md" | grep -q "MIT" || false
}
