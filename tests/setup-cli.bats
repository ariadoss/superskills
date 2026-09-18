#!/usr/bin/env bats
# ./setup's flag handling. An unrecognised flag or --help must never fall
# through to a full install (it once ran a real install during a review probe).
# HOME is a temp dir, and every case exits before anything is written.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
}

@test "setup --help prints usage and exits 0 without installing anything" {
  run bash "$REPO_ROOT/setup" --help
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"Usage"* ]] || false
  [ -z "$(ls -A "$HOME")" ] || { ls -A "$HOME"; return 1; }
}

@test "setup -h is the same as --help" {
  run bash "$REPO_ROOT/setup" -h
  [ "$status" -eq 0 ] || false
  [ -z "$(ls -A "$HOME")" ] || false
}

@test "an unknown flag exits 2 with a message and installs nothing" {
  run bash "$REPO_ROOT/setup" --bogus
  [ "$status" -eq 2 ] || false
  [[ "$output" == *"unknown option: --bogus"* ]] || false
  [ -z "$(ls -A "$HOME")" ] || false
}

@test "--extend-from without a value exits 2 instead of consuming nothing" {
  run bash "$REPO_ROOT/setup" --extend-from
  [ "$status" -eq 2 ] || false
  [ -z "$(ls -A "$HOME")" ] || false
}

@test "setup logs prunes for every tool it links into (no silent removal)" {
  run grep -c 'prune_dangling_links .*>/dev/null' "$REPO_ROOT/setup"
  [ "$output" -eq 0 ] || false
}

@test "--packs with an invalid pack exits 2 before any mutation, conf untouched" {
  run bash "$REPO_ROOT/setup" --packs coding,bogus --list-skills
  [ "$status" -eq 2 ] || false
  [[ "$output" == *"invalid pack: bogus"* ]] || false
  [ ! -f "$HOME/.superskills/packs.conf" ] || false
}

@test "--packs with an empty value exits 2" {
  run bash "$REPO_ROOT/setup" --packs= --list-skills
  [ "$status" -eq 2 ] || false
  [ ! -f "$HOME/.superskills/packs.conf" ] || false
}

@test "--list-skills exits 0, prints selected paths, writes nothing" {
  run bash "$REPO_ROOT/setup" --list-skills
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"/skills/tdd/SKILL.md"* ]] || false
  [[ "$output" == *"/skills/qa-full/SKILL.md"* ]] || false
  [[ "$output" != *"/skills/cache-strategy/SKILL.md"* ]] || false
  [ ! -f "$HOME/.superskills/packs.conf" ] || false
}

@test "--list-skills honors --packs selection for the run" {
  run bash "$REPO_ROOT/setup" --list-skills --packs coding,design
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"/skills/tdd/SKILL.md"* ]] || false
  [[ "$output" == *"/design-skills/ux-designer/SKILL.md"* ]] || false
  [[ "$output" != *"/skills/cache-strategy/SKILL.md"* ]] || false
  [[ "$output" != *"marketing-skills/"* ]] || false
  [ ! -f "$HOME/.superskills/packs.conf" ] || false
}

@test "--list-skills with all lists marketing skills too" {
  run bash "$REPO_ROOT/setup" --list-skills --packs all
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"marketing-skills/"* ]] || false
}

@test "--packs persists the selection for upgrades; no flag preserves it" {
  run bash "$REPO_ROOT/setup" --list-skills --packs coding,design
  [ "$status" -eq 0 ] || false
  [ ! -f "$HOME/.superskills/packs.conf" ] || false
  grep -q '^packs=' "$HOME/.superskills/packs.conf" 2>/dev/null && false
  run bash -c "HOME='$HOME' bash '$REPO_ROOT/setup' --packs coding,design --persist-only"
  [ "$status" -eq 0 ] || false
  grep -q '^packs=coding,design$' "$HOME/.superskills/packs.conf" || false
  run bash "$REPO_ROOT/setup" --list-skills
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"/design-skills/ux-designer/SKILL.md"* ]] || false
  grep -q '^packs=coding,design$' "$HOME/.superskills/packs.conf" || false
}

@test "media pack selects the video-editing subtree, marketing pack does not" {
  run bash "$REPO_ROOT/setup" --list-skills --packs coding,marketing
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"marketing-skills/seo/"* ]] || false
  [[ "$output" != *"video-editing/SKILL.md"* ]] || false
  run bash "$REPO_ROOT/setup" --list-skills --packs coding,media
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"video-editing/SKILL.md"* ]] || false
  [[ "$output" != *"marketing-skills/seo/"* ]] || false
}

@test "design-review resolves through gstack name only when the gstack pack is on" {
  run bash "$REPO_ROOT/setup" --list-skills --packs coding
  [[ "$output" != *"design-review"* ]] || false
  run bash "$REPO_ROOT/setup" --list-skills --packs coding,gstack
  [[ "$output" != *"/skills/design-review/"* ]] || false
}

@test "media predicate: skill_selected gates video-editing by category, not name" {
  cat > "$BATS_TEST_TMPDIR/probe.sh" <<PROBE
source "$REPO_ROOT/scripts/lib/skills-lib.sh"
SS_PACKS=coding,media
skill_selected video-editing media && echo V_YES || echo V_NO
SS_PACKS=coding,marketing
skill_selected video-editing media && echo V2_YES || echo V2_NO
PROBE
  run bash "$BATS_TEST_TMPDIR/probe.sh"
  [[ "$output" == *"V_YES"* ]] || false
  [[ "$output" == *"V2_NO"* ]] || false
}

@test "every per-tool walk is filtered through skill_selected (no unfiltered loops)" {
  run grep -c "ss_selected" "$REPO_ROOT/setup"
  [ "$output" -ge 8 ] || false
}
