#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/scripts/lib/skills-lib.sh"
  export SS_PACKS=coding
  export SS_PACKS_CONF="$BATS_TEST_TMPDIR/packs.conf"
  FIX="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$FIX"
}

@test "coding selects exactly the requested names including external design-review" {
  local name count=0
  for name in specify clarify write-plan analyze repomap dbmap worktrees tdd debug verify test-coverage qa-full finish-branch daily-qa superskills-doctor superskills-upgrade clean-code defense db-optimize web-perf a11y playwright checklist; do
    skill_selected "$name" coding
    count=$((count + 1))
  done
  skill_selected design-review design
  count=$((count + 1))
  [ "$count" -eq 24 ] || false
  run skill_selected cache-strategy core
  [ "$status" -eq 1 ] || false
  run skill_selected review gstack
  [ "$status" -eq 1 ] || false
  run skill_selected tdd marketing
  [ "$status" -eq 1 ] || false
}

@test "pack selection includes coding plus only requested categories" {
  SS_PACKS=coding,design,media
  skill_selected tdd core
  skill_selected typography design
  skill_selected video-editing media
  run skill_selected copywriting marketing
  [ "$status" -eq 1 ] || false
  SS_PACKS=coding,core,gstack
  skill_selected cache-strategy core
  skill_selected review gstack
  run skill_selected typography design
  [ "$status" -eq 1 ] || false
  SS_PACKS=all
  skill_selected copywriting marketing
}

@test "packs_save and packs_load round-trip the comma list as plain data" {
  run packs_save "coding,design"
  [ "$status" -eq 0 ] || false
  grep -q '^packs=coding,design$' "$SS_PACKS_CONF" || false
  run bash -c "set -e; source '$REPO_ROOT/scripts/lib/skills-lib.sh'; SS_PACKS_CONF='$SS_PACKS_CONF'; packs_load; printf '%s' \"\$SS_PACKS\""
  [ "$output" = "coding,design" ] || false
  SS_PACKS=""
  SS_PACKS_CONF="$SS_PACKS_CONF"
  SS_PACKS_DEFAULT="coding,media"
  packs_load
  [ "$SS_PACKS" = "coding,media" ] || false
}

@test "packs_load defaults to coding when conf is absent and survives a missing file" {
  SS_PACKS_CONF="$BATS_TEST_TMPDIR/absent.conf" packs_load
  [ "$SS_PACKS" = "coding" ] || false
}

@test "packs_validate rejects unknown, empty and duplicate-empty lists before any mutation" {
  run packs_validate "coding,bogus"
  [ "$status" -eq 1 ] || false
  [[ "$output" == *"invalid pack: bogus"* ]] || false
  run packs_validate ""
  [ "$status" -eq 1 ] || false
  run packs_validate "coding,,design"
  [ "$status" -eq 1 ] || false
  run packs_validate "coding,design"
  [ "$status" -eq 0 ] || false
}

@test "packs_save collapses any selection containing all to exactly all" {
  packs_save "coding,marketing,all"
  grep -q '^packs=all$' "$SS_PACKS_CONF" || false
}

@test "selected_source_paths resolves only selected skills' SKILL.md paths, read-only" {
  mkdir -p "$FIX/skills/tdd" "$FIX/skills/cache-strategy" "$FIX/design-skills/typography"
  printf '%s\n' '---' 'name: tdd' '---' 'body' > "$FIX/skills/tdd/SKILL.md"
  printf '%s\n' '---' 'name: cache-strategy' '---' 'body' > "$FIX/skills/cache-strategy/SKILL.md"
  printf '%s\n' '---' 'name: typography' '---' 'body' > "$FIX/design-skills/typography/SKILL.md"
  run selected_source_paths "$FIX" "$FIX/skills" "$FIX/design-skills" ""
  [ "$status" -eq 0 ] || false
  [ "$(printf '%s\n' "$output" | grep -c 'skills/tdd/SKILL.md')" -eq 1 ] || false
  [[ "$output" != *"cache-strategy"* ]] || false
  [[ "$output" != *"typography"* ]] || false
  SS_PACKS=all
  run selected_source_paths "$FIX" "$FIX/skills" "$FIX/design-skills" ""
  [[ "$output" == *"cache-strategy"* ]] || false
  [[ "$output" == *"typography"* ]] || false
}

@test "remove_owned_skill removes only our deselected symlinked skill dir and its links" {
  SRC="$FIX/src"; TGT="$FIX/dst"
  mkdir -p "$SRC/gone-skill" "$SRC/keep-skill" "$SRC/foreign-skill"
  printf '%s\n' '---' 'name: gone-skill' '---' > "$SRC/gone-skill/SKILL.md"
  printf '%s\n' 'ref' > "$SRC/gone-skill/extra.md"
  printf '%s\n' '---' 'name: keep-skill' '---' > "$SRC/keep-skill/SKILL.md"
  printf '%s\n' '---' 'name: foreign-skill' '---' > "$SRC/foreign-skill/SKILL.md"
  link_skill_into "$TGT" "$SRC/gone-skill/SKILL.md" "gone-skill" >/dev/null
  link_skill_into "$TGT" "$SRC/keep-skill/SKILL.md" "keep-skill" >/dev/null
  mkdir -p "$TGT/foreign-skill"
  printf '%s\n' 'user file' > "$TGT/foreign-skill/SKILL.md"
  SS_OWNED_SRC="$SRC" run remove_owned_skill "$TGT/foreign-skill" "$TGT/gone-skill"
  [ "$status" -eq 0 ] || false
  [ ! -e "$TGT/gone-skill" ] || false
  [ -f "$TGT/foreign-skill/SKILL.md" ] || false
  [ -d "$TGT/keep-skill" ] || false
  [ -L "$TGT/keep-skill/SKILL.md" ] || false
}

@test "remove_owned_skill never touches a dir holding a regular file, foreign link, link-dir or traversal" {
  SRC="$FIX/src"; TGT="$FIX/dst2"; mkdir -p "$SRC/real"
  mkdir -p "$TGT/has-regular" "$TGT/has-foreign" "$TGT/has-linkdir" "$TGT/has-traversal"
  printf '%s\n' 'regular' > "$TGT/has-regular/SKILL.md"
  ln -s /etc/hostname "$TGT/has-foreign/SKILL.md"
  mkdir -p "$FIX/other-tree"
  ln -s "$FIX/other-tree" "$TGT/has-linkdir/SKILL.md"
  ln -s "$SRC/real/../../etc/hostname" "$TGT/has-traversal/SKILL.md"
  SS_OWNED_SRC="$SRC" run remove_owned_skill "$TGT/has-regular" "$TGT/has-foreign" "$TGT/has-linkdir" "$TGT/has-traversal"
  [ "$status" -eq 0 ] || false
  [ -f "$TGT/has-regular/SKILL.md" ] || false
  [ -L "$TGT/has-foreign/SKILL.md" ] || false
  [ -L "$TGT/has-linkdir/SKILL.md" ] || false
  [ -L "$TGT/has-traversal/SKILL.md" ] || false
  [ -d "$TGT/has-regular" ] || false
}
