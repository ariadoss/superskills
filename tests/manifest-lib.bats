#!/usr/bin/env bats
# Unit tests for scripts/lib/manifest-lib.sh — the superskills-marketing plugin
# is a flat shim tree (plugin-skills/<frontmatter-name> → ../<path>) plus a
# manifest, because Claude Code names plugin skills by directory basename and
# does not recurse into nested skill directories.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/scripts/lib/manifest-lib.sh"

  MK="$BATS_TEST_TMPDIR/marketing-skills"
  mkdir -p "$MK/seo/local" "$MK/pages/marketing/pricing" "$MK/pages/legal/privacy" "$MK/ads/google" "$MK/ads/README-only"
  printf -- '---\nname: local-seo\n---\n' > "$MK/seo/local/SKILL.md"
  printf -- '---\nname: pricing-page-generator\n---\n' > "$MK/pages/marketing/pricing/SKILL.md"
  printf -- '---\nname: privacy-page-generator\n---\n' > "$MK/pages/legal/privacy/SKILL.md"
  printf -- 'no frontmatter here\n' > "$MK/ads/google/SKILL.md"
  printf 'not a skill\n' > "$MK/ads/README-only/README.md"
  printf 'reference\n' > "$MK/seo/local/reference.md"
}

@test "skill_entries maps frontmatter name → relative dir, basename when name is absent, sorted" {
  run skill_entries "$MK"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'google\tads/google\nlocal-seo\tseo/local\npricing-page-generator\tpages/marketing/pricing\nprivacy-page-generator\tpages/legal/privacy')" ]
}

@test "write_marketing_shims creates one relative symlink per skill named by frontmatter name" {
  run write_marketing_shims "$MK"
  [ "$status" -eq 0 ]
  [ -L "$MK/plugin-skills/local-seo" ]
  [ "$(readlink "$MK/plugin-skills/local-seo")" = "../seo/local" ]
  [ -f "$MK/plugin-skills/local-seo/SKILL.md" ]
  [ -f "$MK/plugin-skills/local-seo/reference.md" ]       # sibling files come along
  [ -L "$MK/plugin-skills/pricing-page-generator" ]
  [ "$(ls "$MK/plugin-skills" | wc -l | tr -d ' ')" -eq 4 ]
  [ ! -e "$MK/plugin-skills/README-only" ]
}

@test "write_marketing_shims is a rebuild: stale links are removed" {
  write_marketing_shims "$MK"
  rm -rf "$MK/pages/legal"
  write_marketing_shims "$MK"
  [ ! -e "$MK/plugin-skills/privacy-page-generator" ]
  [ "$(ls "$MK/plugin-skills" | wc -l | tr -d ' ')" -eq 3 ]
}

@test "write_marketing_shims fails loudly on two skills with the same name" {
  mkdir -p "$MK/content/local"; printf -- '---\nname: local-seo\n---\n' > "$MK/content/local/SKILL.md"
  run write_marketing_shims "$MK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"local-seo"* ]] || false
}

@test "write_marketing_shims refuses a frontmatter name that would escape plugin-skills/" {
  mkdir -p "$MK/seo/evil"; printf -- '---\nname: ../../escape\n---\n' > "$MK/seo/evil/SKILL.md"
  run write_marketing_shims "$MK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"escape"* ]] || false
  [ ! -e "$MK/escape" ]
}

@test "write_marketing_shims refuses names that start with - or . (option look-alikes, hidden entries)" {
  for bad in "-" "--help" ".hidden"; do
    rm -rf "$MK/seo/evil"; mkdir -p "$MK/seo/evil"; printf -- '---\nname: %s\n---\n' "$bad" > "$MK/seo/evil/SKILL.md"
    run write_marketing_shims "$MK"
    [ "$status" -eq 1 ] || { echo "accepted '$bad'"; return 1; }
  done
}

@test "write_marketing_shims refuses an empty or missing root instead of touching /" {
  run write_marketing_shims ""
  [ "$status" -eq 1 ]
  run write_marketing_shims "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -eq 1 ]
}

@test "write_marketing_shims and write_marketing_manifest reuse pre-computed entries instead of re-walking the tree" {
  entries="$(printf 'local-seo\tseo/local\n')"
  run write_marketing_shims "$MK" "$entries"
  [ "$status" -eq 0 ]
  [ "$(ls "$MK/plugin-skills" | wc -l | tr -d ' ')" -eq 1 ]      # only the passed entry, not all 4 on disk
  OUT="$MK/.claude-plugin/plugin.json"
  run write_marketing_manifest "$MK" "9.9.9" "$OUT" 99
  grep -q '"description": "The 99 marketing skills' "$OUT"
}

@test "skill_entries uses the shared batch name parser (proven equal to skill_name_from in skills-lib.bats)" {
  run grep -c 'skill_names_from_files' "$REPO_ROOT/scripts/lib/manifest-lib.sh"
  [ "$output" -ge 1 ] || false
  run grep -c "grep -m1 '\^name:'" "$REPO_ROOT/scripts/lib/manifest-lib.sh"
  [ "$output" -eq 0 ] || false
}

@test "write_marketing_shims catches duplicate names that are not adjacent (locale-independent)" {
  entries="$(printf 'a\tseo/local\nac\tpages/marketing/pricing\na\tpages/legal/privacy\n')"
  run write_marketing_shims "$MK" "$entries"
  [ "$status" -eq 1 ]
  [[ "$output" == *"'a'"* ]] || false
  [ ! -e "$MK/seo/local/privacy" ]          # no link written inside a source dir
  [ ! -L "$MK/pages/legal/privacy/privacy" ]
}

@test "skill_entries and marketing_skill_files sort bytewise (LC_ALL=C) so output is identical on every platform" {
  run grep -c 'LC_ALL=C sort' "$REPO_ROOT/scripts/lib/manifest-lib.sh" "$REPO_ROOT/scripts/lib/skills-lib.sh"
  [[ "$output" != *":0"* ]] || false
}

@test "write_marketing_shims keeps the existing tree when the new input is invalid" {
  write_marketing_shims "$MK"
  before="$(ls "$MK/plugin-skills")"
  mkdir -p "$MK/seo/evil"; printf -- '---\nname: ../escape\n---\n' > "$MK/seo/evil/SKILL.md"
  run write_marketing_shims "$MK"
  [ "$status" -eq 1 ] || false
  [ "$(ls "$MK/plugin-skills")" = "$before" ] || false
  run write_marketing_shims "$MK" "$(printf 'dup\tseo/local\ndup\tads/google\n')"
  [ "$status" -eq 1 ] || false
  [ "$(ls "$MK/plugin-skills")" = "$before" ] || false
}

@test "skill_entries ignores the shim tree itself" {
  write_marketing_shims "$MK"
  [ "$(skill_entries "$MK" | wc -l | tr -d ' ')" -eq 4 ]
}

@test "write_marketing_manifest writes valid JSON pointing at the shim dir with the version" {
  OUT="$MK/.claude-plugin/plugin.json"
  run write_marketing_manifest "$MK" "9.9.9" "$OUT"
  [ "$status" -eq 0 ]
  if command -v jq >/dev/null 2>&1; then
    [ "$(jq -r .version "$OUT")" = "9.9.9" ]
    [ "$(jq -r .name "$OUT")" = "superskills-marketing" ]
    [ "$(jq -r '.skills | join(",")' "$OUT")" = "./plugin-skills" ]
    [[ "$(jq -r .description "$OUT")" == "The 4 marketing skills"* ]]   # count derived, not hardcoded || false
  else
    grep -q '"version": "9.9.9"' "$OUT"; grep -q '"./plugin-skills"' "$OUT"
  fi
}

@test "the committed shim tree matches the real marketing-skills tree (run scripts/sync-marketing-manifest.sh if this fails)" {
  REAL="$REPO_ROOT/marketing-skills"
  [ -d "$REAL/plugin-skills" ]
  expected="$(skill_entries "$REAL")"
  actual="$(cd "$REAL/plugin-skills" && for l in *; do printf '%s\t%s\n' "$l" "$(readlink "$l" | sed 's|^\.\./||')"; done | sort)"
  [ "$expected" = "$actual" ]
  # every link resolves
  for l in "$REAL"/plugin-skills/*; do [ -f "$l/SKILL.md" ] || { echo "dangling: $l"; return 1; }; done
}
