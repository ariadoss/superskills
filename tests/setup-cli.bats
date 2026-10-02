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

@test "setup manages ~/.zcode/skills as a link target with the full contract" {
  # ZCode is a first-class target: dir-gated like Codex, core + gstack
  # closure linked, and its dangling links pruned with logging (never
  # silently) for both the source tree and the gstack install.
  run grep -c 'ZCODE_SKILLS_DIR="\$HOME/\.zcode/skills"' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
  run grep -c 'if \[ -d "\$HOME/\.zcode" \]' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
  run grep -c 'prune_dangling_links "\$ZCODE_SKILLS_DIR" "\$SOURCE_DIR"' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
  run grep -c 'prune_dangling_links "\$ZCODE_SKILLS_DIR" "\$GSTACK_DIR"' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
  # The gstack-closure walk is what distinguishes this target from the Codex
  # block: without it setup silently stops linking /qa's toolchain into ZCode.
  run grep -c 'link_zcode_filtered "\$skill_md" "\$dir_name" gstack' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
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

@test "--packs persists the selection for upgrades; a plain run stamps the loaded default" {
  run bash "$REPO_ROOT/setup" --list-skills --packs coding,design
  [ "$status" -eq 0 ] || false
  [ ! -f "$HOME/.superskills/packs.conf" ] || false
  run bash -c "HOME='$HOME' bash '$REPO_ROOT/setup' --packs coding,design --persist-only"
  [ "$status" -eq 0 ] || false
  grep -q '^packs=coding,design$' "$HOME/.superskills/packs.conf" || false
  run bash "$REPO_ROOT/setup" --list-skills
  [ "$status" -eq 0 ] || false
  [[ "$output" == *"/design-skills/ux-designer/SKILL.md"* ]] || false
  grep -q '^packs=coding,design$' "$HOME/.superskills/packs.conf" || false
  # Every FULL run must persist the effective selection (not only --packs
  # runs): without it, a fresh default install has no packs.conf and the
  # doctor misreads it as a pre-packs install. bats cannot run the full
  # installer (it clones), so this pins the call itself.
  run grep -c 'packs_save "\${SS_PACKS:-coding}"' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
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
  # design-review exists only in gstack, never in this repo's trees, so
  # --list-skills can never print it; the real gate is gstack_pack_action,
  # unit-tested in tests/profiles.bats and wired into setup's gstack section.
  run grep -c "gstack_pack_action" "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
}

@test "--list-skills stdout is pure paths (the banner never reaches it)" {
  run bash "$REPO_ROOT/setup" --list-skills
  [ "$status" -eq 0 ] || false
  [[ "$output" != *"superskills setup"* ]] || false
}

@test "a plain run emits no shell errors (PACKS_GIVEN and friends initialised)" {
  run bash "$REPO_ROOT/setup" --list-skills
  [ "$status" -eq 0 ] || false
  [[ "$output" != *"integer expression"* ]] || false
  [[ "$output" != *"unbound variable"* ]] || false
}

@test "the deselected prune runs for every tool dir (Claude, OpenCode, Codex, ZCode, DSH) plus gstack" {
  run grep -c "prune_deselected_skills" "$REPO_ROOT/setup"
  [ "$output" -eq 9 ] || false
  # Gated on a persisted selection: a pre-packs install is never mass-pruned.
  run grep -c 'CONFIG_DIR/packs.conf' "$REPO_ROOT/setup"
  [ "$output" -eq 9 ] || false
  # Dangling gstack links are pruned ungated (must clean up after clone removal).
  run grep -cF 'prune_dangling_links "$CLAUDE_SKILLS_DIR" "$GSTACK_DIR"' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
  # The gstack walk runs only from a validated install, never a partial dir.
  run grep -cF 'real|vendor) walk_flat_claude "$GSTACK_DIR" gstack' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
}

@test "the Codex target links whole skill folders (the only shape codex discovers)" {
  # Codex follows symlinked skill folders but never a symlinked SKILL.md
  # inside a real directory (verified on codex 0.157.1). A regression to
  # link_skill_into would link skills codex never loads — silently.
  run grep -c 'link_skill_dir_into "\$CODEX_SKILLS_DIR"' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
  run grep -c 'link_skill_into "\$CODEX_SKILLS_DIR"' "$REPO_ROOT/setup"
  [ "$output" -eq 0 ] || false
}

@test "setup's missing-clearwing banner stays optional-scoped (never 'needed for /pentest')" {
  # Same regression pin as the doctor one: clearwing is optional (gated,
  # billed provider); the old banner claimed it was needed for /pentest.
  # Whole-file greps — the banner's line wrapping must not affect the pin.
  run grep -c 'needed for /pentest' "$REPO_ROOT/setup"
  [ "$output" -eq 0 ] || false
  run grep -qF 'uv tool install clearwing' "$REPO_ROOT/setup"
  [ "$status" -eq 0 ] || false
  run grep -qF 'clearwing not found' "$REPO_ROOT/setup"
  [ "$status" -eq 0 ] || false
  # The spend-safety claim of the bridge reframe: only provider-driven runs
  # bill, and they are ask-first.
  run grep -qF 'ask-first' "$REPO_ROOT/setup"
  [ "$status" -eq 0 ] || { echo "missing spend-gate wording: ask-first"; return 1; }
  run grep -qF 'bundled' "$REPO_ROOT/setup"
  [ "$status" -eq 0 ] || { echo "missing bridge wording: bundled"; return 1; }
}

@test "setup manages ~/.dsh/skills as a link target with the full contract" {
  # DSH (DeepSeek Harness) is a first-class target like ZCode/Codex: dir-gated,
  # the full pack selection linked as whole folders (its local provider reads
  # <name>/SKILL.md directory bundles), and dangling links pruned with logging
  # for both the source tree and the gstack install.
  run grep -c 'DSH_SKILLS_DIR="\$HOME/\.dsh/skills"' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
  run grep -c 'if \[ -d "\$HOME/\.dsh" \]' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
  run grep -c 'link_skill_dir_into "\$DSH_SKILLS_DIR"' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
  run grep -c 'link_skill_into "\$DSH_SKILLS_DIR"' "$REPO_ROOT/setup"
  [ "$output" -eq 0 ] || false
  run grep -c 'prune_dangling_links "\$DSH_SKILLS_DIR" "\$SOURCE_DIR"' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
  run grep -c 'prune_dangling_links "\$DSH_SKILLS_DIR" "\$GSTACK_DIR"' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
  # The gstack-closure walk is what keeps /qa's toolchain linked into DSH.
  run grep -c 'link_dsh_filtered "\$skill_md" "\$dir_name" gstack' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
}

@test "a real install links the coding pack into ~/.dsh/skills as dir symlinks" {
  # Behavioral pin: with ~/.dsh present, setup links skill folders whose
  # SKILL.md resolves into the repo tree — the shape DSH's local provider
  # discovers at its user-dsh root.
  mkdir -p "$HOME/.dsh"
  run bash "$REPO_ROOT/setup" -q --no-knowledge < /dev/null
  [ "$status" -eq 0 ] || false
  [ -L "$HOME/.dsh/skills/tdd" ] || false
  [ -f "$HOME/.dsh/skills/tdd/SKILL.md" ] || false
  [[ "$(readlink "$HOME/.dsh/skills/tdd")" == *"/skills/tdd" ]] || false
  [ -f "$HOME/.dsh/skills/qa-full/SKILL.md" ] || false
  [ ! -e "$HOME/.dsh/skills/node_modules" ] || false
}

@test "setup without ~/.dsh never creates the DSH skills dir" {
  run bash "$REPO_ROOT/setup" -q --no-knowledge < /dev/null
  [ "$status" -eq 0 ] || false
  [ ! -e "$HOME/.dsh" ] || false
}

@test "workflow rule targets are per-harness instruction files" {
  # Source contract: the developer-workflow block writes each detected
  # harness's own instruction file (CLAUDE.md for Claude Code, the primary
  # target; AGENTS.md for the dir-gated harnesses), gated by top-level dir,
  # never by a second bare `if [ -d ~/.zcode ]` (those pins belong to the
  # skills blocks).
  run grep -c 'for wf_rel in \.claude/CLAUDE\.md \.zcode/AGENTS\.md \.codex/AGENTS\.md \.dsh/AGENTS\.md' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
  run grep -c 'WORKFLOW_MARKER=' "$REPO_ROOT/setup"
  [ "$output" -eq 1 ] || false
}

@test "a real install writes the workflow rule to every detected harness's instruction file" {
  # Behavioral pin: ~/.claude/CLAUDE.md always (primary target, created if
  # absent); ~/.{zcode,codex,dsh}/AGENTS.md only when the harness is present.
  mkdir -p "$HOME/.zcode" "$HOME/.codex" "$HOME/.dsh"
  run bash "$REPO_ROOT/setup" -q --no-knowledge < /dev/null
  [ "$status" -eq 0 ] || false
  for f in .claude/CLAUDE.md .zcode/AGENTS.md .codex/AGENTS.md .dsh/AGENTS.md; do
    grep -qF '<!-- superskills-workflow-rule -->' "$HOME/$f" || { echo "missing workflow rule: $HOME/$f"; return 1; }
  done
}

@test "the workflow rule is dir-gated: absent harnesses get no instruction file" {
  mkdir -p "$HOME/.zcode"
  run bash "$REPO_ROOT/setup" -q --no-knowledge < /dev/null
  [ "$status" -eq 0 ] || false
  grep -qF '<!-- superskills-workflow-rule -->' "$HOME/.claude/CLAUDE.md" || false
  grep -qF '<!-- superskills-workflow-rule -->' "$HOME/.zcode/AGENTS.md" || false
  [ ! -e "$HOME/.codex" ] || false
  [ ! -e "$HOME/.dsh" ] || false
}

@test "re-running setup never duplicates the workflow rule" {
  mkdir -p "$HOME/.zcode"
  run bash "$REPO_ROOT/setup" -q --no-knowledge < /dev/null
  [ "$status" -eq 0 ] || false
  run bash "$REPO_ROOT/setup" -q --no-knowledge < /dev/null
  [ "$status" -eq 0 ] || false
  [ "$(grep -cF '<!-- superskills-workflow-rule -->' "$HOME/.claude/CLAUDE.md")" -eq 1 ] || false
  [ "$(grep -cF '<!-- superskills-workflow-rule -->' "$HOME/.zcode/AGENTS.md")" -eq 1 ] || false
}

@test "an unwritable instruction file is skipped, never aborts the install" {
  # A chmod-000 ~/.claude/CLAUDE.md makes the marker grep fail (treated as
  # marker-absent) and the append fail. The install must still exit 0 with a
  # logged skip: one bad config file cannot retroactively fail a successful
  # skills link.
  mkdir -p "$HOME/.claude"
  printf 'existing instructions\n' > "$HOME/.claude/CLAUDE.md"
  chmod 000 "$HOME/.claude/CLAUDE.md"
  run bash "$REPO_ROOT/setup" -q --no-knowledge < /dev/null
  [ "$status" -eq 0 ] || { echo "setup aborted on unwritable instruction file"; return 1; }
  # The Claude target links files inside a real skills dir (not dir symlinks).
  [ -f "$HOME/.claude/skills/tdd/SKILL.md" ] || false
  chmod 644 "$HOME/.claude/CLAUDE.md"
  [ "$(cat "$HOME/.claude/CLAUDE.md")" = "existing instructions" ] || { echo "unwritable file was modified"; return 1; }
}
