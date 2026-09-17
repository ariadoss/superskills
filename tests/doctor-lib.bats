#!/usr/bin/env bats
# Unit tests for scripts/lib/doctor-lib.sh — the read-only readiness checks
# behind /superskills-doctor. Hermetic: a fixture repo + fake home under
# BATS_TEST_TMPDIR; no real HOME, no network, no `claude` binary.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/scripts/lib/doctor-lib.sh"

  # Fixture repo: VERSION, setup, two skills, three manifests.
  ROOT="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$ROOT/skills/alpha" "$ROOT/skills/beta" "$ROOT/.claude-plugin" "$ROOT/.codex-plugin" "$ROOT/scripts/git-hooks"
  printf '2.24.0\n' > "$ROOT/VERSION"
  printf '#!/bin/sh\n' > "$ROOT/setup"; chmod +x "$ROOT/setup"
  printf -- '---\nname: alpha\ndescription: a\n---\n' > "$ROOT/skills/alpha/SKILL.md"
  printf -- '---\nname: beta\ndescription: b\n---\n' > "$ROOT/skills/beta/SKILL.md"
  printf '{ "name": "superskills", "version": "2.24.0" }\n' > "$ROOT/.claude-plugin/plugin.json"
  printf '{ "name": "superskills", "plugins": [{ "version": "2.24.0" }] }\n' > "$ROOT/.claude-plugin/marketplace.json"
  printf '{ "name": "superskills", "version": "2.24.0" }\n' > "$ROOT/.codex-plugin/plugin.json"
  mkdir -p "$ROOT/.cursor-plugin" "$ROOT/marketing-skills/.claude-plugin"
  printf '{ "name": "superskills", "version": "2.24.0" }\n' > "$ROOT/.cursor-plugin/plugin.json"
  printf '{ "name": "superskills", "version": "2.24.0" }\n' > "$ROOT/.cursor-plugin/marketplace.json"
  printf '{ "name": "superskills-marketing", "version": "2.24.0" }\n' > "$ROOT/marketing-skills/.claude-plugin/plugin.json"
  printf '# superskills post-merge hook\n' > "$ROOT/scripts/git-hooks/post-merge"

  # Fake home with a linked install of both skills.
  HOME_DIR="$BATS_TEST_TMPDIR/home"
  SKILLS="$HOME_DIR/.claude/skills"
  mkdir -p "$SKILLS/alpha" "$SKILLS/beta"
  ln -s "$ROOT/skills/alpha/SKILL.md" "$SKILLS/alpha/SKILL.md"
  ln -s "$ROOT/skills/beta/SKILL.md" "$SKILLS/beta/SKILL.md"
}

status_of() { printf '%s\n' "$1" | cut -f2; }
# Portable (POSIX cksum, no md5/md5sum) snapshot of names, file contents,
# symlink targets and modes — changes to any of them change the snapshot.
tree_snapshot() {
  find "$@" \( -type f -exec cksum {} + \) -o \( -type l -exec sh -c 'for l; do printf "%s -> %s\n" "$l" "$(readlink "$l")"; done' _ {} + \) -o -print | LC_ALL=C sort
  find "$@" -exec ls -ld {} + 2>/dev/null | awk '{print $1, $NF}' | LC_ALL=C sort
}
evidence_of() { printf '%s\n' "$1" | cut -f3-; }

# ── repo ──

@test "check_repo: ready with version when VERSION, setup and skills/ exist" {
  run doctor_check_repo "$ROOT"
  [ "$status" -eq 0 ]
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"2.24.0"* ]] || false
}

@test "check_repo: blocked when the root is not a superskills checkout, with a runnable reinstall command" {
  run doctor_check_repo "$BATS_TEST_TMPDIR/nope"
  [ "$(status_of "$output")" = "blocked" ]
  [[ "$(evidence_of "$output")" == *"cd ~/.claude/skills/superskills && ./setup"* ]] || false
  [[ "$(evidence_of "$output")" != *"cd there"* ]] || false
}

# ── install kind ──

@test "install_kind: canonical when the repo is the managed clone" {
  mkdir -p "$SKILLS"
  ln -s "$ROOT" "$SKILLS/superskills"
  run doctor_install_kind "$ROOT" "$SKILLS"
  [ "$output" = "canonical" ]
}

@test "install_kind: dev-repo when skills are symlinked from elsewhere" {
  run doctor_install_kind "$ROOT" "$SKILLS"
  [ "$output" = "dev-repo" ]
}

@test "install_kind: unlinked when nothing points at the repo" {
  run doctor_install_kind "$ROOT" "$BATS_TEST_TMPDIR/empty"
  [ "$output" = "unlinked" ]
}

@test "check_install: blocked and tells you to run ./setup when unlinked" {
  run doctor_check_install "$ROOT" "$BATS_TEST_TMPDIR/empty"
  [ "$(status_of "$output")" = "blocked" ]
  [[ "$(evidence_of "$output")" == *"./setup"* ]] || false
}

# ── plugin-only install (claude plugin install …, ./setup never run) ──

@test "install_kind: plugin when nothing is linked but the plugin is installed" {
  run doctor_install_kind "$ROOT" "$BATS_TEST_TMPDIR/empty" "2.24.0"
  [ "$output" = "plugin" ]
}

@test "install_kind: plugin when the root itself lives in a plugin cache" {
  C="$BATS_TEST_TMPDIR/cfg/plugins/cache/superskills/superskills/2.24.0"; mkdir -p "$C"; cp -R "$ROOT/." "$C/"
  run doctor_install_kind "$C" "$BATS_TEST_TMPDIR/empty" ""
  [ "$output" = "plugin" ]
}

@test "plugin-only install: Install and Links are ready, gstack is a warning, verdict is not blocked" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  fake_plugin_list "$FAKE" "superskills@superskills=2.24.0"
  EMPTY_HOME="$BATS_TEST_TMPDIR/plugin-home"; mkdir -p "$EMPTY_HOME"
  run doctor_report "$ROOT" "$EMPTY_HOME" "$FAKE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| Install | ready | plugin install"* ]] || false
  [[ "$output" == *"| Links | ready |"* ]] || false
  [[ "$output" == *"| gstack | warning |"* ]] || false
  [[ "$output" == *"| Plugin | ready | plugin superskills@superskills v2.24.0 matches VERSION"* ]] || false
  [[ "$output" == *"Verdict: ready with warnings"* ]] || false
}

# ── links ──

@test "check_links: ready when every skill resolves to the repo" {
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"2/2"* ]] || false
}

@test "check_links: blocked when a new skill has no link yet (needs ./setup)" {
  mkdir -p "$ROOT/skills/gamma"
  printf -- '---\nname: gamma\ndescription: g\n---\n' > "$ROOT/skills/gamma/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "blocked" ]
  [[ "$(evidence_of "$output")" == *"gamma"* ]] || false
  [[ "$(evidence_of "$output")" == *"./setup"* ]] || false
}

@test "check_links: blocked when a link is dangling" {
  rm "$ROOT/skills/beta/SKILL.md"; rmdir "$ROOT/skills/beta"
  mkdir -p "$ROOT/skills/beta"; printf -- '---\nname: beta\n---\n' > "$ROOT/skills/beta/SKILL.md"
  rm "$SKILLS/beta/SKILL.md"; ln -s "$ROOT/skills/beta/GONE.md" "$SKILLS/beta/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "blocked" ]
  [[ "$(evidence_of "$output")" == *"beta"* ]] || false
}

@test "check_links: a dangling design-skills link is blocked, not ready (setup links design-skills too)" {
  mkdir -p "$ROOT/design-skills/gamma-dir" "$SKILLS/gamma"
  printf -- '---\nname: gamma\n---\n' > "$ROOT/design-skills/gamma-dir/SKILL.md"
  ln -s "$ROOT/design-skills/renamed-away/SKILL.md" "$SKILLS/gamma/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "blocked" ]
  [[ "$(evidence_of "$output")" == *"Dangling: gamma"* ]] || false
}

@test "check_links: an unlinked marketing skill (nested) is reported, and linked ones count" {
  mkdir -p "$ROOT/marketing-skills/seo/local" "$ROOT/marketing-skills/pages/legal/privacy" "$SKILLS/local-seo"
  printf -- '---\nname: local-seo\n---\n' > "$ROOT/marketing-skills/seo/local/SKILL.md"
  printf -- '---\nname: privacy-page-generator\n---\n' > "$ROOT/marketing-skills/pages/legal/privacy/SKILL.md"
  ln -s "$ROOT/marketing-skills/seo/local/SKILL.md" "$SKILLS/local-seo/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "blocked" ]
  [[ "$(evidence_of "$output")" == *"3/4 skills linked"* ]] || false
  [[ "$(evidence_of "$output")" == *"privacy-page-generator"* ]] || false
}

@test "check_links: the plugin-skills shim tree is not double-counted as marketing skills" {
  mkdir -p "$ROOT/marketing-skills/seo/local" "$ROOT/marketing-skills/plugin-skills" "$SKILLS/local-seo"
  printf -- '---\nname: local-seo\n---\n' > "$ROOT/marketing-skills/seo/local/SKILL.md"
  ln -s ../seo/local "$ROOT/marketing-skills/plugin-skills/local-seo"
  ln -s "$ROOT/marketing-skills/seo/local/SKILL.md" "$SKILLS/local-seo/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"3/3"* ]] || false
}

@test "check_links: plugin install counts core and design skills served by the loader" {
  mkdir -p "$ROOT/design-skills/gamma-dir"; printf -- '---\nname: gamma\n---\n' > "$ROOT/design-skills/gamma-dir/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS" plugin
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == "3 skills served by the plugin loader"* ]] || false
}

@test "check_links: a link that resolves into a different checkout is a warning naming it" {
  OTHER="$BATS_TEST_TMPDIR/other-checkout/skills/beta"; mkdir -p "$OTHER"
  printf -- '---\nname: beta\n---\n' > "$OTHER/SKILL.md"
  rm "$SKILLS/beta/SKILL.md"; ln -s "$OTHER/SKILL.md" "$SKILLS/beta/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"beta"* ]] || false
  [[ "$(evidence_of "$output")" == *"other-checkout"* ]] || false
}

@test "check_links: stale links left by a moved checkout are a warning (listed, never deleted)" {
  mkdir -p "$SKILLS/old-skill"; ln -s "$BATS_TEST_TMPDIR/moved-away/skills/old-skill/SKILL.md" "$SKILLS/old-skill/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"old-skill"* ]] || false
  [ -L "$SKILLS/old-skill/SKILL.md" ]
}

@test "check_links: a name shared by two sources is reported as shadowed, status follows setup's override" {
  mkdir -p "$ROOT/design-skills/alpha-design"
  printf -- '---\nname: alpha\n---\n' > "$ROOT/design-skills/alpha-design/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"shadowed"* ]] || false
  [[ "$(evidence_of "$output")" == *"alpha"* ]] || false
}

@test "check_links: uses the frontmatter name, not the directory name" {
  mkdir -p "$ROOT/skills/delta-dir" "$SKILLS/delta-name"
  printf -- '---\nname: delta-name\n---\n' > "$ROOT/skills/delta-dir/SKILL.md"
  ln -s "$ROOT/skills/delta-dir/SKILL.md" "$SKILLS/delta-name/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "ready" ]
}

# ── manifests ──

@test "check_manifests: ready when every manifest matches VERSION" {
  run doctor_check_manifests "$ROOT"
  [ "$(status_of "$output")" = "ready" ]
}

@test "check_manifests: warning naming the stale file and sync-version.sh" {
  printf '{ "name": "superskills", "version": "2.23.0" }\n' > "$ROOT/.codex-plugin/plugin.json"
  run doctor_check_manifests "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *".codex-plugin/plugin.json"* ]] || false
  [[ "$(evidence_of "$output")" == *"sync-version.sh"* ]] || false
}

@test "check_manifests: warning naming a manifest that is missing altogether (not silently ready)" {
  rm "$ROOT/.claude-plugin/marketplace.json"
  run doctor_check_manifests "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"missing"* ]] || false
  [[ "$(evidence_of "$output")" == *".claude-plugin/marketplace.json"* ]] || false
}

# ── gstack ──

@test "check_gstack: ready on a real clone" {
  G="$HOME_DIR/.claude/skills/gstack"; mkdir -p "$G/.git"; printf '1.80.0\n' > "$G/VERSION"
  run doctor_check_gstack "$G"
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"1.80.0"* ]] || false
}

@test "check_gstack: warning on the vendor stopgap" {
  G="$HOME_DIR/.claude/skills/gstack"; mkdir -p "$G"; printf '1.80.0\n' > "$G/VERSION"; touch "$G/.superskills-vendor-copy"
  run doctor_check_gstack "$G"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"vendor"* ]] || false
}

@test "check_gstack: blocked when absent or partial" {
  run doctor_check_gstack "$HOME_DIR/.claude/skills/gstack"
  [ "$(status_of "$output")" = "blocked" ]
  G="$HOME_DIR/.claude/skills/gstack"; mkdir -p "$G"
  run doctor_check_gstack "$G"
  [ "$(status_of "$output")" = "blocked" ]
}

# ── marketing shim tree (committed symlinks) ──

@test "check_shims: ready when plugin-skills entries are real symlinks that resolve" {
  mkdir -p "$ROOT/marketing-skills/seo/local" "$ROOT/marketing-skills/plugin-skills"
  printf -- '---\nname: local-seo\n---\n' > "$ROOT/marketing-skills/seo/local/SKILL.md"
  ln -s ../seo/local "$ROOT/marketing-skills/plugin-skills/local-seo"
  run doctor_check_shims "$ROOT"
  [ "$(status_of "$output")" = "ready" ]
}

@test "check_shims: warning when a symlink was materialised as a text file (Windows without core.symlinks)" {
  mkdir -p "$ROOT/marketing-skills/seo/local" "$ROOT/marketing-skills/plugin-skills"
  printf -- '---\nname: local-seo\n---\n' > "$ROOT/marketing-skills/seo/local/SKILL.md"
  printf '../seo/local' > "$ROOT/marketing-skills/plugin-skills/local-seo"
  run doctor_check_shims "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"core.symlinks"* ]] || false
}

@test "check_shims: warning when a plugin-skills entry is a dangling symlink" {
  mkdir -p "$ROOT/marketing-skills/plugin-skills"
  ln -s ../seo/does-not-exist "$ROOT/marketing-skills/plugin-skills/ghost"
  run doctor_check_shims "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"dangling"* ]] || false
  [[ "$(evidence_of "$output")" == *"sync-marketing-manifest.sh"* ]] || false
}

@test "check_shims: warning when plugin-skills/ is empty but marketing skills exist (interrupted sync)" {
  mkdir -p "$ROOT/marketing-skills/seo/local" "$ROOT/marketing-skills/plugin-skills"
  printf -- '---\nname: local-seo\n---\n' > "$ROOT/marketing-skills/seo/local/SKILL.md"
  run doctor_check_shims "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"0 of 1"* ]] || false
  [[ "$(evidence_of "$output")" == *"sync-marketing-manifest.sh"* ]] || false
}

@test "check_shims: warning when plugin-skills/ is partial" {
  mkdir -p "$ROOT/marketing-skills/seo/local" "$ROOT/marketing-skills/seo/entity" "$ROOT/marketing-skills/plugin-skills"
  printf -- '---\nname: local-seo\n---\n' > "$ROOT/marketing-skills/seo/local/SKILL.md"
  printf -- '---\nname: entity-seo\n---\n' > "$ROOT/marketing-skills/seo/entity/SKILL.md"
  ln -s ../seo/local "$ROOT/marketing-skills/plugin-skills/local-seo"
  run doctor_check_shims "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"1 of 2"* ]] || false
}

@test "check_shims: extra resolving entries beyond the marketing skill count do not claim an interrupted sync" {
  mkdir -p "$ROOT/marketing-skills/seo/local" "$ROOT/marketing-skills/plugin-skills" "$BATS_TEST_TMPDIR/extra"
  printf -- '---\nname: local-seo\n---\n' > "$ROOT/marketing-skills/seo/local/SKILL.md"
  printf -- '---\nname: extra\n---\n' > "$BATS_TEST_TMPDIR/extra/SKILL.md"
  ln -s ../seo/local "$ROOT/marketing-skills/plugin-skills/local-seo"
  ln -s "$BATS_TEST_TMPDIR/extra" "$ROOT/marketing-skills/plugin-skills/extra"
  run doctor_check_shims "$ROOT"
  [[ "$(evidence_of "$output")" != *"interrupted"* ]] || false
}

@test "check_shims: warning when marketing skills exist but plugin-skills/ is missing entirely" {
  mkdir -p "$ROOT/marketing-skills/seo/local"
  printf -- '---\nname: local-seo\n---\n' > "$ROOT/marketing-skills/seo/local/SKILL.md"
  run doctor_check_shims "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
}

@test "check_shims: ready with a note when the checkout has no marketing shim tree (older checkout)" {
  run doctor_check_shims "$ROOT"
  [ "$(status_of "$output")" = "ready" ]
}

# ── commands ──

@test "check_command: ready when present, warning when missing (optional)" {
  run doctor_check_command "bash" "needed for everything"
  [ "$(status_of "$output")" = "ready" ]
  run doctor_check_command "definitely-not-a-command-xyz" "needed for /fuzz"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"/fuzz"* ]] || false
}

# ── knowledge bases ──

@test "check_knowledge: ready with 'none configured' when the conf is absent or empty" {
  run doctor_check_knowledge "$HOME_DIR/.superskills/knowledge.conf" "$HOME_DIR"
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"none configured"* ]] || false
}

@test "check_knowledge: warning naming the configured base that is not cloned" {
  CONF="$HOME_DIR/.superskills/knowledge.conf"; mkdir -p "$(dirname "$CONF")"
  printf '# comment\nkb1|~/.superskills/knowledge/kb1|desc|https://example.invalid/kb1.git\n' > "$CONF"
  run doctor_check_knowledge "$CONF" "$HOME_DIR"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"kb1"* ]] || false
}

# ── plugin (claude CLI) ──

@test "check_plugin: unverified when the claude CLI is not available" {
  run doctor_check_plugin "$ROOT" "definitely-not-claude-xyz"
  [ "$(status_of "$output")" = "unverified" ]
}

@test "check_plugin: ready when not installed as a plugin (setup-linked install is fine)" {
  FAKE="$BATS_TEST_TMPDIR/claude"; printf '#!/bin/sh\necho "[]"\n' > "$FAKE"; chmod +x "$FAKE"
  run doctor_check_plugin "$ROOT" "$FAKE"
  [ "$(status_of "$output")" = "ready" ]
}

# The real CLI pretty-prints (spaces after colons, one key per line) and lists
# sibling plugins such as superskills-marketing first; the parser must cope.
fake_plugin_list() {
  local file="$1"; shift
  { printf '#!/bin/sh\ncat <<JSON\n[\n'; local first=1
    for entry in "$@"; do
      [ "$first" -eq 1 ] || printf ',\n'; first=0
      printf '  {\n    "id": "%s",\n    "version": "%s",\n    "scope": "user",\n    "enabled": true\n  }' "${entry%%=*}" "${entry#*=}"
    done
    printf '\n]\nJSON\n'; } > "$file"; chmod +x "$file"
}

@test "check_plugin: warning when the installed plugin version lags VERSION (pretty-printed JSON, sibling plugin first)" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  fake_plugin_list "$FAKE" "superskills-marketing@superskills=2.24.0" "superskills@superskills=2.20.0"
  run doctor_check_plugin "$ROOT" "$FAKE"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"2.20.0"* ]] || false
}

@test "check_plugin: ready when the installed plugin matches VERSION" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  fake_plugin_list "$FAKE" "superskills@superskills=2.24.0"
  run doctor_check_plugin "$ROOT" "$FAKE"
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"matches VERSION"* ]] || false
}

@test "_doctor_plugin_version: survives a nested object and a } inside a string between id and version" {
  run _doctor_plugin_version '[{"id":"superskills@superskills","author":{"name":"D"},"description":"has a } brace","version":"2.24.0"}]' "superskills@"
  [ "$output" = "2.24.0" ]
  run _doctor_plugin_version "$(printf '[\n  {\n    "id": "other@x",\n    "version": "9.9.9"\n  },\n  {\n    "id": "superskills@superskills",\n    "source": { "source": "url", "url": "https://x.invalid" },\n    "version": "2.24.0"\n  }\n]')" "superskills@"
  [ "$output" = "2.24.0" ]
  run _doctor_plugin_version '[]' "superskills@"
  [ -z "$output" ]
}

@test "a CLI that prints an error and exits 0 is unverified, not 'not installed'" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  printf '#!/bin/sh\necho "Error: could not reach marketplace registry (offline)"\nexit 0\n' > "$FAKE"; chmod +x "$FAKE"
  run doctor_check_plugin "$ROOT" "$FAKE"
  [ "$(status_of "$output")" = "unverified" ]
  run doctor_report "$ROOT" "$HOME_DIR" "$FAKE"
  [[ "$output" == *"| Plugin | unverified |"* ]] || false
}

@test "doctor_report scans for the install kind once (doctor_check_install accepts a precomputed kind)" {
  run doctor_check_install "$ROOT" "$BATS_TEST_TMPDIR/empty" "" dev-repo
  [[ "$(evidence_of "$output")" == "dev-repo install"* ]] || false
  run grep -c 'doctor_install_kind "' "$REPO_ROOT/scripts/lib/doctor-lib.sh"
  [ "$output" -eq 2 ]   # the one in doctor_report, and the fallback inside doctor_check_install
}

@test "install: a canonical install plus the plugin install is also a warning" {
  ln -s "$ROOT" "$SKILLS/superskills"
  run doctor_check_install "$ROOT" "$SKILLS" "2.24.0"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"canonical install"* ]] || false
  [[ "$(evidence_of "$output")" == *"twice"* ]] || false
}

@test "install: a ./setup install plus the plugin install is a warning (every skill appears twice)" {
  run doctor_check_install "$ROOT" "$SKILLS" "2.24.0"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"twice"* ]] || false
}

@test "check_plugin: accepts pre-fetched JSON so doctor_report calls the CLI only once" {
  run doctor_check_plugin "$ROOT" "definitely-not-claude-xyz" '[{"id":"superskills@superskills","version":"2.24.0"}]'
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"matches VERSION"* ]] || false
}

@test "doctor_report invokes the claude CLI exactly once" {
  FAKE="$BATS_TEST_TMPDIR/claude"; LOG="$BATS_TEST_TMPDIR/calls"
  printf '#!/bin/sh\necho call >> "%s"\necho "[]"\n' "$LOG" > "$FAKE"; chmod +x "$FAKE"
  run doctor_report "$ROOT" "$HOME_DIR" "$FAKE"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$LOG" | tr -d ' ')" -eq 1 ]
}

@test "doctor_report does not hang on a CLI that never returns (bounded by a timeout)" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  printf '#!/bin/sh\nsleep 30\n' > "$FAKE"; chmod +x "$FAKE"
  DOCTOR_CLI_TIMEOUT=1 run doctor_report "$ROOT" "$HOME_DIR" "$FAKE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| Plugin | unverified |"* ]] || false
}

@test "check_plugin: a sibling plugin alone does not count as the superskills plugin" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  fake_plugin_list "$FAKE" "superskills-marketing@superskills=2.24.0"
  run doctor_check_plugin "$ROOT" "$FAKE"
  [[ "$(evidence_of "$output")" == *"not installed as a Claude Code plugin"* ]] || false
}

@test "check_knowledge: expands ~ against the inspected home, not the real HOME" {
  CONF="$HOME_DIR/.superskills/knowledge.conf"; mkdir -p "$(dirname "$CONF")" "$HOME_DIR/.superskills/knowledge/kb1/.git"
  printf 'kb1|~/.superskills/knowledge/kb1|desc|https://example.invalid/kb1.git\n' > "$CONF"
  run doctor_check_knowledge "$CONF" "$HOME_DIR"
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"all cloned"* ]] || false
}

# ── hook ──

@test "check_hook: warning when the root is not a git checkout" {
  run doctor_check_hook "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"not a git checkout"* ]] || false
}

@test "check_hook: warning when the checkout has no post-merge hook" {
  git -C "$ROOT" init -q
  run doctor_check_hook "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"not installed"* ]] || false
}

@test "check_hook: ready when our post-merge hook is installed" {
  git -C "$ROOT" init -q
  cp "$ROOT/scripts/git-hooks/post-merge" "$ROOT/.git/hooks/post-merge"; chmod +x "$ROOT/.git/hooks/post-merge"
  run doctor_check_hook "$ROOT"
  [ "$(status_of "$output")" = "ready" ]
}

@test "check_hook: warning when a foreign post-merge hook is installed (ours is not running)" {
  git -C "$ROOT" init -q
  printf '#!/bin/sh\necho someone else\n' > "$ROOT/.git/hooks/post-merge"
  run doctor_check_hook "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
}

# ── verdict ──

@test "verdict: blocked if any required row is blocked, even with everything else ready" {
  rows=$(printf 'Repo\tready\tok\nLinks\tblocked\tbad\nbun\tready\tok\n')
  run doctor_verdict "$rows"
  [ "$output" = "blocked" ]
}

@test "verdict: a non-required blocked row is a warning, even after a required blocked row was seen" {
  # Latent flag-carry bug: the per-row required check must not reuse the
  # accumulated `blocked` flag from an earlier row.
  run doctor_verdict "$(printf 'Links\tblocked\tx\nffuf\tblocked\tx\n')"
  [ "$output" = "blocked" ]
  run doctor_verdict "$(printf 'ffuf\tblocked\tx\nbats\tready\tx\n')"
  [ "$output" = "ready with warnings" ]
}

@test "verdict: unverified beats warning; warning beats ready" {
  run doctor_verdict "$(printf 'A\tready\tx\nB\tunverified\tx\nC\twarning\tx\n')"
  [ "$output" = "unverified" ]
  run doctor_verdict "$(printf 'A\tready\tx\nC\twarning\tx\n')"
  [ "$output" = "ready with warnings" ]
  run doctor_verdict "$(printf 'A\tready\tx\nC\tready\tx\n')"
  [ "$output" = "ready" ]
}

# ── report (end-to-end, no claude binary) ──

@test "doctor_report never mutates the tree and renders a table with a verdict" {
  before="$(tree_snapshot "$ROOT" "$HOME_DIR")"
  run doctor_report "$ROOT" "$HOME_DIR" "definitely-not-claude-xyz"
  [ "$status" -eq 0 ]
  after="$(tree_snapshot "$ROOT" "$HOME_DIR")"
  [ "$before" = "$after" ]
  [[ "$output" == *"| Check"* ]] || false
  [[ "$output" == *"Verdict:"* ]] || false
  # gstack is absent in this fixture, so the verdict must not be "ready"
  [[ "$output" != *"Verdict: ready"* ]] || false
}

# ── scripts/doctor.sh wrapper (arg parsing; the report itself is tested above) ──

@test "doctor.sh: --root and --home point the report at another checkout and home" {
  FAKE="$BATS_TEST_TMPDIR/claude"; printf '#!/bin/sh\necho "[]"\n' > "$FAKE"; chmod +x "$FAKE"
  run bash "$REPO_ROOT/scripts/doctor.sh" --root "$ROOT" --home "$HOME_DIR" --bin "$FAKE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"superskills v2.24.0 at $ROOT"* ]] || false
  [[ "$output" == *"| Plugin | ready | not installed"* ]] || false
  [[ "$output" == *"linked into $SKILLS"* ]] || false
}

@test "doctor.sh: --root=/--home= forms are accepted" {
  run bash "$REPO_ROOT/scripts/doctor.sh" "--root=$ROOT" "--home=$HOME_DIR" --bin=definitely-not-claude-xyz
  [ "$status" -eq 0 ]
  [[ "$output" == *"| Plugin | unverified |"* ]] || false
  [[ "$output" == *"at $ROOT"* ]] || false
}

@test "doctor.sh: an unknown option exits 2 with a message" {
  run bash "$REPO_ROOT/scripts/doctor.sh" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option: --bogus"* ]] || false
}

@test "doctor.sh: --help prints usage and exits 0" {
  run bash "$REPO_ROOT/scripts/doctor.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--root"* ]] || false
}

# ── rounds found by Codex (outside-model review) ──

@test "doctor_report does not mutate the tree even when a file's content changes would be the only difference (snapshot sees contents)" {
  a="$(tree_snapshot "$ROOT")"; printf 'x' >> "$ROOT/VERSION"; b="$(tree_snapshot "$ROOT")"
  [ "$a" != "$b" ] || false
}

@test "check_plugin: without jq the plugin state is a warning asking for jq, never ready or not-installed" {
  FAKE="$BATS_TEST_TMPDIR/claude"; fake_plugin_list "$FAKE" "superskills@superskills=2.24.0"
  DOCTOR_JQ=definitely-not-jq run doctor_check_plugin "$ROOT" "$FAKE"
  [ "$(status_of "$output")" = "warning" ] || false
  [[ "$(evidence_of "$output")" == *"jq"* ]] || false
}

@test "a CLI that prints malformed JSON ([}, trailing comma) and exits 0 is unverified" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  for bad in '[}' '[,]' '[{"id":"superskills@superskills","version":"2.24.0",}]'; do
    printf '#!/bin/sh\nprintf %%s %s\nexit 0\n' "'$bad'" > "$FAKE"; chmod +x "$FAKE"
    run doctor_check_plugin "$ROOT" "$FAKE"
    [ "$(status_of "$output")" = "unverified" ] || { echo "$bad -> $output"; return 1; }
  done
}

@test "check_plugin: an installed but disabled plugin is a warning, and does not make the install a plugin install" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  printf '#!/bin/sh\necho %s\n' "'[{\"id\":\"superskills@superskills\",\"version\":\"2.24.0\",\"enabled\":false}]'" > "$FAKE"; chmod +x "$FAKE"
  run doctor_check_plugin "$ROOT" "$FAKE"
  [ "$(status_of "$output")" = "warning" ] || false
  [[ "$(evidence_of "$output")" == *"disabled"* ]] || false
  EMPTY_HOME="$BATS_TEST_TMPDIR/plugin-home"; mkdir -p "$EMPTY_HOME"
  run doctor_report "$ROOT" "$EMPTY_HOME" "$FAKE"
  [[ "$output" == *"| Install | blocked |"* ]] || false
}

@test "--home: the plugin CLI is asked about the inspected home, not the caller's" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  cat > "$FAKE" <<'SH'
#!/bin/sh
if [ -f "$HOME/.fake-plugins.json" ]; then cat "$HOME/.fake-plugins.json"; else echo "[]"; fi
SH
  chmod +x "$FAKE"
  CALLER="$BATS_TEST_TMPDIR/caller"; INSPECTED="$BATS_TEST_TMPDIR/inspected"; mkdir -p "$CALLER" "$INSPECTED"
  printf '[{"id":"superskills@superskills","version":"2.24.0","enabled":true}]' > "$CALLER/.fake-plugins.json"
  HOME="$CALLER" run doctor_report "$ROOT" "$INSPECTED" "$FAKE"
  [[ "$output" == *"| Install | blocked |"* ]] || false
  [[ "$output" == *"| Plugin | ready | not installed"* ]] || false
}

@test "install_kind: a cache-shaped path does not override a successful 'not installed' answer from the CLI" {
  C="$BATS_TEST_TMPDIR/x/plugins/cache/superskills/superskills/2.24.0"; mkdir -p "$C"; cp -R "$ROOT/." "$C/"
  run doctor_install_kind "$C" "$BATS_TEST_TMPDIR/empty" "" ok
  [ "$output" = "unlinked" ] || false
  run doctor_install_kind "$C" "$BATS_TEST_TMPDIR/empty" "" unavailable
  [ "$output" = "plugin" ] || false
}

@test "check_links: a link to a different skill inside this checkout is blocked, naming both" {
  rm "$SKILLS/beta/SKILL.md"; ln -s "$ROOT/skills/alpha/SKILL.md" "$SKILLS/beta/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "blocked" ] || false
  [[ "$(evidence_of "$output")" == *"beta"* ]] || false
  [[ "$(evidence_of "$output")" == *"skills/alpha/SKILL.md"* ]] || false
}

@test "check_links: a shadowed name must link to setup's winner (skills > design > marketing)" {
  mkdir -p "$ROOT/design-skills/alpha-design"; printf -- '---\nname: alpha\n---\n' > "$ROOT/design-skills/alpha-design/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"          # alpha links to skills/alpha — the winner
  [ "$(status_of "$output")" = "ready" ] || false
  rm "$SKILLS/alpha/SKILL.md"; ln -s "$ROOT/design-skills/alpha-design/SKILL.md" "$SKILLS/alpha/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"          # now the loser is linked
  [ "$(status_of "$output")" = "blocked" ] || false
}

@test "check_manifests: an empty manifest or one with no version field is a warning" {
  : > "$ROOT/.codex-plugin/plugin.json"
  run doctor_check_manifests "$ROOT"
  [ "$(status_of "$output")" = "warning" ] || false
  [[ "$(evidence_of "$output")" == *".codex-plugin/plugin.json"* ]] || false
  printf '{ "name": "superskills" }\n' > "$ROOT/.codex-plugin/plugin.json"
  run doctor_check_manifests "$ROOT"
  [ "$(status_of "$output")" = "warning" ] || false
}

@test "check_manifests: invalid JSON is a warning even when it contains the right version (jq present)" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  printf '{ "name": "superskills", "version": "2.24.0", }\n' > "$ROOT/.codex-plugin/plugin.json"
  run doctor_check_manifests "$ROOT"
  [ "$(status_of "$output")" = "warning" ] || false
  [[ "$(evidence_of "$output")" == *"invalid JSON"* ]] || false
}

@test "check_shims: a renamed marketing skill whose old shim still resolves is a warning (name→target mapping, not counts)" {
  mkdir -p "$ROOT/marketing-skills/seo/local" "$ROOT/marketing-skills/plugin-skills"
  printf -- '---\nname: local-seo-renamed\n---\n' > "$ROOT/marketing-skills/seo/local/SKILL.md"
  ln -s ../seo/local "$ROOT/marketing-skills/plugin-skills/local-seo"
  run doctor_check_shims "$ROOT"
  [ "$(status_of "$output")" = "warning" ] || false
  [[ "$(evidence_of "$output")" == *"local-seo-renamed"* ]] || false
}

@test "check_shims: two shims pointing at one skill cannot hide a missing one" {
  mkdir -p "$ROOT/marketing-skills/seo/local" "$ROOT/marketing-skills/seo/entity" "$ROOT/marketing-skills/plugin-skills"
  printf -- '---\nname: local-seo\n---\n' > "$ROOT/marketing-skills/seo/local/SKILL.md"
  printf -- '---\nname: entity-seo\n---\n' > "$ROOT/marketing-skills/seo/entity/SKILL.md"
  ln -s ../seo/local "$ROOT/marketing-skills/plugin-skills/local-seo"
  ln -s ../seo/local "$ROOT/marketing-skills/plugin-skills/entity-seo"
  run doctor_check_shims "$ROOT"
  [ "$(status_of "$output")" = "warning" ] || false
  [[ "$(evidence_of "$output")" == *"entity-seo"* ]] || false
}

@test "check_hook: a hook that is not executable is a warning (git will not run it)" {
  git -C "$ROOT" init -q
  cp "$ROOT/scripts/git-hooks/post-merge" "$ROOT/.git/hooks/post-merge"; chmod -x "$ROOT/.git/hooks/post-merge"
  run doctor_check_hook "$ROOT"
  [ "$(status_of "$output")" = "warning" ] || false
  [[ "$(evidence_of "$output")" == *"executable"* ]] || false
}

@test "the CLI probe is bounded even when the CLI leaves a child holding stdout open" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  printf '#!/bin/sh\nsleep 30 &\nsleep 30\n' > "$FAKE"; chmod +x "$FAKE"
  start=$(date +%s)
  DOCTOR_CLI_TIMEOUT=1 run _doctor_cli_json "$FAKE"
  elapsed=$(( $(date +%s) - start ))
  [ "$output" = "__unavailable__" ] || false
  [ "$elapsed" -le 5 ] || { echo "took ${elapsed}s"; return 1; }
}


@test "check_links: a SKILL.md that is a directory is reported, and skills after it are still checked" {
  mkdir -p "$ROOT/skills/delta/SKILL.md" "$ROOT/skills/zeta"
  printf -- '---\nname: zeta\n---\n' > "$ROOT/skills/zeta/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "blocked" ] || false
  [[ "$(evidence_of "$output")" == *"delta"* ]] || false
  [[ "$(evidence_of "$output")" == *"zeta"* ]] || false      # unlinked skill after the bad one still reported
}

@test "plugin install: an unreadable or directory SKILL.md is blocked, not 'served'" {
  mkdir -p "$ROOT/skills/delta/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS" plugin
  [ "$(status_of "$output")" = "blocked" ] || false
  [[ "$(evidence_of "$output")" == *"delta"* ]] || false
}

@test "plugin install: zero skills found is blocked, not 'ready — 0 skills served'" {
  E="$BATS_TEST_TMPDIR/emptyroot"; mkdir -p "$E/skills"
  run doctor_check_links "$E" "$SKILLS" plugin
  [ "$(status_of "$output")" = "blocked" ] || false
}

@test "check_plugin: without jq, a plugin install (cache path) is unverified, not a warning" {
  FAKE="$BATS_TEST_TMPDIR/claude"; fake_plugin_list "$FAKE" "superskills@superskills=2.24.0"
  DOCTOR_JQ=definitely-not-jq run doctor_check_plugin "$ROOT" "$FAKE" '[]' plugin
  [ "$(status_of "$output")" = "unverified" ] || false
  DOCTOR_JQ=definitely-not-jq run doctor_check_plugin "$ROOT" "$FAKE" '[]' dev-repo
  [ "$(status_of "$output")" = "warning" ] || false
}

@test "plugin install: Links validates the CLI's installPath, not an unrelated --root" {
  CACHE="$BATS_TEST_TMPDIR/plugin-cache/superskills/superskills/2.24.0"
  mkdir -p "$CACHE/skills/onlyskill"
  printf -- '---\nname: onlyskill\n---\n' > "$CACHE/skills/onlyskill/SKILL.md"
  FAKE="$BATS_TEST_TMPDIR/claude"
  printf '#!/bin/sh\necho %s\n' "'[{\"id\":\"superskills@superskills\",\"version\":\"2.24.0\",\"enabled\":true,\"installPath\":\"$CACHE\"}]'" > "$FAKE"; chmod +x "$FAKE"
  EMPTY_HOME="$BATS_TEST_TMPDIR/plugin-home2"; mkdir -p "$EMPTY_HOME"
  run doctor_report "$ROOT" "$EMPTY_HOME" "$FAKE"
  [[ "$output" == *"| Links | ready | 1 skills served by the plugin loader from $CACHE"* ]] || { echo "$output"; return 1; }
  [[ "$output" != *"$ROOT/skills"* ]] || false
}

@test "plugin install: no installPath in the CLI's answer falls back to --root, and says so" {
  FAKE="$BATS_TEST_TMPDIR/claude"; fake_plugin_list "$FAKE" "superskills@superskills=2.24.0"
  EMPTY_HOME="$BATS_TEST_TMPDIR/plugin-home3"; mkdir -p "$EMPTY_HOME"
  run doctor_report "$ROOT" "$EMPTY_HOME" "$FAKE"
  [[ "$output" == *"| Links | ready | 2 skills served by the plugin loader from $ROOT/skills"* ]] || false
  [[ "$output" == *"unconfirmed"* ]] || false
}

@test "check_manifests: a top-level object with no top-level version, only a nested one, is a warning" {
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  printf '{ "name": "superskills", "source": { "version": "2.24.0" } }\n' > "$ROOT/.codex-plugin/plugin.json"
  run doctor_check_manifests "$ROOT"
  [ "$(status_of "$output")" = "warning" ] || false
  [[ "$(evidence_of "$output")" == *".codex-plugin/plugin.json"* ]] || false
}

@test "check_repo: blocked when VERSION is missing even though setup and skills/ exist" {
  rm "$ROOT/VERSION"
  run doctor_check_repo "$ROOT"
  [ "$(status_of "$output")" = "blocked" ] || false
}

@test "install_kind: a path merely containing /plugins/ is not a plugin cache" {
  C="$BATS_TEST_TMPDIR/somewhere/plugins/other/checkout"; mkdir -p "$C"; cp -R "$ROOT/." "$C/"
  run doctor_install_kind "$C" "$BATS_TEST_TMPDIR/empty" ""
  [ "$output" = "unlinked" ] || false
}

@test "check_knowledge: an existing non-git directory is still reported as not cloned" {
  CONF="$HOME_DIR/.superskills/knowledge.conf"; mkdir -p "$(dirname "$CONF")" "$HOME_DIR/.superskills/knowledge/kb1"
  printf 'kb1|~/.superskills/knowledge/kb1|desc|https://example.invalid/kb1.git\n' > "$CONF"
  run doctor_check_knowledge "$CONF" "$HOME_DIR"
  [ "$(status_of "$output")" = "warning" ] || false
}

@test "doctor_report renders every expected row" {
  run doctor_report "$ROOT" "$HOME_DIR" "definitely-not-claude-xyz"
  for row in Repo Install Links Manifests "Marketing shims" gstack Plugin "Post-merge hook" "Knowledge bases"; do
    [[ "$output" == *"| $row |"* ]] || { echo "missing row: $row"; return 1; }
  done
}

@test "install_kind: a real (non-symlink) SKILL.md is not dev-repo evidence" {
  # Isolated from the suite's own dev-repo fixture links: a fresh, otherwise-empty skills dir.
  ISO="$BATS_TEST_TMPDIR/iso-skills"; mkdir -p "$ISO/faketwin"
  printf -- '---\nname: faketwin\n---\n' > "$ISO/faketwin/SKILL.md"   # a real file, not a link
  run doctor_install_kind "$ROOT" "$ISO"
  [ "$output" != "dev-repo" ] || { echo "a plain file was taken as dev-repo evidence"; return 1; }
}

@test "install_kind: a plain (non-symlink) copy of a skill nested inside root is not dev-repo evidence" {
  mkdir -p "$ROOT/fake-skills-nested"
  cp "$ROOT/skills/alpha/SKILL.md" "$ROOT/fake-skills-nested/SKILL.md"   # a real file whose own realpath IS under $ROOT
  run doctor_install_kind "$ROOT" "$ROOT/fake-skills-nested"
  [ "$output" != "dev-repo" ] || { echo "a plain file resolved under root was taken as dev-repo evidence"; return 1; }
}

@test "plugin install: an unreadable (chmod 000) regular SKILL.md is blocked, not served" {
  mkdir -p "$ROOT/skills/epsilon"
  printf -- '---\nname: epsilon\n---\n' > "$ROOT/skills/epsilon/SKILL.md"
  chmod 000 "$ROOT/skills/epsilon/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS" plugin
  chmod 644 "$ROOT/skills/epsilon/SKILL.md"   # restore so cleanup can remove it
  [ "$(status_of "$output")" = "blocked" ] || false
  [[ "$(evidence_of "$output")" == *"epsilon"* ]] || false
}

@test "check_links: a resolving link belonging to another tool is never called stale" {
  OTHER="$BATS_TEST_TMPDIR/other-tool-real/SKILL.md"; mkdir -p "$(dirname "$OTHER")"; printf 'x\n' > "$OTHER"
  mkdir -p "$SKILLS/other-tool"; ln -s "$OTHER" "$SKILLS/other-tool/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [[ "$(evidence_of "$output")" != *"other-tool"* ]] || { echo "$output"; return 1; }
}

@test "_doctor_run_bounded kills the whole process group, not just the direct child" {
  MARKER="$BATS_TEST_TMPDIR/grandchild-alive"
  cat > "$BATS_TEST_TMPDIR/forker.sh" <<SH
#!/bin/sh
( while [ -e "$MARKER" ] || true; do :; done ) &
echo \$! > "$BATS_TEST_TMPDIR/grandchild.pid"
touch "$MARKER"
sleep 30
SH
  chmod +x "$BATS_TEST_TMPDIR/forker.sh"
  ( _doctor_run_bounded 1 "$BATS_TEST_TMPDIR/out" "$BATS_TEST_TMPDIR/forker.sh" ) &
  runner=$!
  for i in $(seq 1 50); do [ -f "$BATS_TEST_TMPDIR/grandchild.pid" ] && break; sleep 0.1; done
  gcpid="$(cat "$BATS_TEST_TMPDIR/grandchild.pid" 2>/dev/null)"
  wait "$runner" || true   # the bounded run is expected to return 124 (killed)
  sleep 0.3
  if [ -n "$gcpid" ]; then
    run kill -0 "$gcpid"
    [ "$status" -ne 0 ] || { echo "grandchild $gcpid still alive after the bounded run returned"; kill -9 "$gcpid" 2>/dev/null; return 1; }
  fi
}
