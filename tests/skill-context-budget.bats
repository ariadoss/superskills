#!/usr/bin/env bats
setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  R="$BATS_TEST_TMPDIR/repo"; mkdir -p "$R/skills/alpha"
  printf -- '---\nname: alpha\ndescription: Does alpha.\n---\n# A\nbody\n' > "$R/skills/alpha/SKILL.md"
  printf 'side file\n' > "$R/skills/alpha/ref.md"
}

@test "reports frontmatter, body and side-file bytes per skill, then totals" {
  run bash "$REPO_ROOT/scripts/skill-context-budget.sh" "$R"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'alpha\t'* ]] || false
  [[ "$output" == *"TOTAL"* ]] || false
  fm="$(printf -- '---\nname: alpha\ndescription: Does alpha.\n---\n' | wc -c | tr -d ' ')"
  [[ "$output" == *$'alpha\t'"$fm"$'\t'* ]] || false
  [[ "$output" == *$'alpha\t'"$fm"$'\t9\t10'* ]] || false
  [[ "$output" == *$'TOTAL\t'"$fm"$'\t9\t10'* ]] || false
}
