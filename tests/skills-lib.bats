#!/usr/bin/env bats
# Unit tests for scripts/lib/skills-lib.sh — the skill name/desc/body resolution
# and symlink logic used by setup. Fully hermetic: a fixture skill tree and a
# temp target dir under BATS_TEST_TMPDIR, no real HOME, no network.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  load_lib() { source "$REPO_ROOT/scripts/lib/skills-lib.sh"; }
  load_lib

  FIX="$BATS_TEST_TMPDIR/src"
  TARGET="$BATS_TEST_TMPDIR/dst"
  mkdir -p "$FIX" "$TARGET"

  # Skill with an explicit `name:` and a sibling extra file.
  mkdir -p "$FIX/alpha"
  cat > "$FIX/alpha/SKILL.md" <<'EOF'
---
name: alpha-cmd
description: Does the alpha thing well.
---
# Alpha
body line 1
body line 2
EOF
  printf 'ref\n' > "$FIX/alpha/reference.md"

  # Skill with no `name:` field (must fall back to the provided name).
  mkdir -p "$FIX/beta"
  cat > "$FIX/beta/SKILL.md" <<'EOF'
---
description: |
  A block-form description whose first
  real line should be extracted.
---
# Beta
EOF
}

@test "skill_name_from reads the name: frontmatter" {
  run skill_name_from "$FIX/alpha/SKILL.md" "fallback-name"
  [ "$status" -eq 0 ]
  [ "$output" = "alpha-cmd" ]
}

@test "skill_name_from falls back when no name: field" {
  run skill_name_from "$FIX/beta/SKILL.md" "beta"
  [ "$status" -eq 0 ]
  [ "$output" = "beta" ]
}

@test "skill_desc_from reads a single-line description" {
  run skill_desc_from "$FIX/alpha/SKILL.md"
  [ "$output" = "Does the alpha thing well." ]
}

@test "skill_desc_from extracts first line of a block description" {
  run skill_desc_from "$FIX/beta/SKILL.md"
  [ "$output" = "A block-form description whose first" ]
}

@test "skill_body_from returns content after the second fence" {
  run skill_body_from "$FIX/alpha/SKILL.md"
  [[ "$output" == *"# Alpha"* ]]
  [[ "$output" == *"body line 1"* ]]
  [[ "$output" != *"name: alpha-cmd"* ]]
}

@test "link_skill_into links SKILL.md under the resolved name" {
  run link_skill_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback"
  [ "$status" -eq 0 ]
  [ "$output" = "alpha-cmd" ]
  [ -L "$TARGET/alpha-cmd/SKILL.md" ]
  [ "$(readlink "$TARGET/alpha-cmd/SKILL.md")" = "$FIX/alpha/SKILL.md" ]
}

@test "link_skill_into links sibling extras by default" {
  link_skill_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback" >/dev/null
  [ -L "$TARGET/alpha-cmd/reference.md" ]
}

@test "link_skill_into with link_extras=0 links only SKILL.md" {
  link_skill_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback" 0 >/dev/null
  [ -L "$TARGET/alpha-cmd/SKILL.md" ]
  [ ! -e "$TARGET/alpha-cmd/reference.md" ]
}

@test "link_skill_into applies a name prefix (opencode style)" {
  link_skill_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback" 0 "superskills-" >/dev/null
  [ -L "$TARGET/superskills-alpha-cmd/SKILL.md" ]
}

@test "link_skill_into uses the fallback name when no name: field" {
  run link_skill_into "$TARGET" "$FIX/beta/SKILL.md" "beta-fallback"
  [ "$output" = "beta-fallback" ]
  [ -L "$TARGET/beta-fallback/SKILL.md" ]
}

@test "link_skill_into is idempotent (re-link does not error)" {
  link_skill_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback" >/dev/null
  run link_skill_into "$TARGET" "$FIX/alpha/SKILL.md" "fallback"
  [ "$status" -eq 0 ]
  [ -L "$TARGET/alpha-cmd/SKILL.md" ]
}
