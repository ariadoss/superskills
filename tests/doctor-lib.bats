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
evidence_of() { printf '%s\n' "$1" | cut -f3-; }

# ── repo ──

@test "check_repo: ready with version when VERSION, setup and skills/ exist" {
  run doctor_check_repo "$ROOT"
  [ "$status" -eq 0 ]
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"2.24.0"* ]]
}

@test "check_repo: blocked when the root is not a superskills checkout, with a runnable reinstall command" {
  run doctor_check_repo "$BATS_TEST_TMPDIR/nope"
  [ "$(status_of "$output")" = "blocked" ]
  [[ "$(evidence_of "$output")" == *"cd ~/.claude/skills/superskills && ./setup"* ]]
  [[ "$(evidence_of "$output")" != *"cd there"* ]]
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
  [[ "$(evidence_of "$output")" == *"./setup"* ]]
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
  [[ "$output" == *"| Install | ready | plugin install"* ]]
  [[ "$output" == *"| Links | ready |"* ]]
  [[ "$output" == *"| gstack | warning |"* ]]
  [[ "$output" == *"| Plugin | ready | plugin superskills@superskills v2.24.0 matches VERSION"* ]]
  [[ "$output" == *"Verdict: ready with warnings"* ]]
}

# ── links ──

@test "check_links: ready when every skill resolves to the repo" {
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"2/2"* ]]
}

@test "check_links: blocked when a new skill has no link yet (needs ./setup)" {
  mkdir -p "$ROOT/skills/gamma"
  printf -- '---\nname: gamma\ndescription: g\n---\n' > "$ROOT/skills/gamma/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "blocked" ]
  [[ "$(evidence_of "$output")" == *"gamma"* ]]
  [[ "$(evidence_of "$output")" == *"./setup"* ]]
}

@test "check_links: blocked when a link is dangling" {
  rm "$ROOT/skills/beta/SKILL.md"; rmdir "$ROOT/skills/beta"
  mkdir -p "$ROOT/skills/beta"; printf -- '---\nname: beta\n---\n' > "$ROOT/skills/beta/SKILL.md"
  rm "$SKILLS/beta/SKILL.md"; ln -s "$ROOT/skills/beta/GONE.md" "$SKILLS/beta/SKILL.md"
  run doctor_check_links "$ROOT" "$SKILLS"
  [ "$(status_of "$output")" = "blocked" ]
  [[ "$(evidence_of "$output")" == *"beta"* ]]
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
  [[ "$(evidence_of "$output")" == *".codex-plugin/plugin.json"* ]]
  [[ "$(evidence_of "$output")" == *"sync-version.sh"* ]]
}

@test "check_manifests: warning naming a manifest that is missing altogether (not silently ready)" {
  rm "$ROOT/.claude-plugin/marketplace.json"
  run doctor_check_manifests "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"missing"* ]]
  [[ "$(evidence_of "$output")" == *".claude-plugin/marketplace.json"* ]]
}

# ── gstack ──

@test "check_gstack: ready on a real clone" {
  G="$HOME_DIR/.claude/skills/gstack"; mkdir -p "$G/.git"; printf '1.80.0\n' > "$G/VERSION"
  run doctor_check_gstack "$G"
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"1.80.0"* ]]
}

@test "check_gstack: warning on the vendor stopgap" {
  G="$HOME_DIR/.claude/skills/gstack"; mkdir -p "$G"; printf '1.80.0\n' > "$G/VERSION"; touch "$G/.superskills-vendor-copy"
  run doctor_check_gstack "$G"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"vendor"* ]]
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
  [[ "$(evidence_of "$output")" == *"core.symlinks"* ]]
}

@test "check_shims: warning when a plugin-skills entry is a dangling symlink" {
  mkdir -p "$ROOT/marketing-skills/plugin-skills"
  ln -s ../seo/does-not-exist "$ROOT/marketing-skills/plugin-skills/ghost"
  run doctor_check_shims "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"dangling"* ]]
  [[ "$(evidence_of "$output")" == *"sync-marketing-manifest.sh"* ]]
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
  [[ "$(evidence_of "$output")" == *"/fuzz"* ]]
}

# ── knowledge bases ──

@test "check_knowledge: ready with 'none configured' when the conf is absent or empty" {
  run doctor_check_knowledge "$HOME_DIR/.superskills/knowledge.conf" "$HOME_DIR"
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"none configured"* ]]
}

@test "check_knowledge: warning naming the configured base that is not cloned" {
  CONF="$HOME_DIR/.superskills/knowledge.conf"; mkdir -p "$(dirname "$CONF")"
  printf '# comment\nkb1|~/.superskills/knowledge/kb1|desc|https://example.invalid/kb1.git\n' > "$CONF"
  run doctor_check_knowledge "$CONF" "$HOME_DIR"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"kb1"* ]]
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
  [[ "$(evidence_of "$output")" == *"2.20.0"* ]]
}

@test "check_plugin: ready when the installed plugin matches VERSION" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  fake_plugin_list "$FAKE" "superskills@superskills=2.24.0"
  run doctor_check_plugin "$ROOT" "$FAKE"
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"matches VERSION"* ]]
}

@test "_doctor_plugin_version: survives a nested object and a } inside a string between id and version" {
  run _doctor_plugin_version '[{"id":"superskills@superskills","author":{"name":"D"},"description":"has a } brace","version":"2.24.0"}]' "superskills@"
  [ "$output" = "2.24.0" ]
  run _doctor_plugin_version "$(printf '[\n  {\n    "id": "other@x",\n    "version": "9.9.9"\n  },\n  {\n    "id": "superskills@superskills",\n    "source": { "source": "url", "url": "https://x.invalid" },\n    "version": "2.24.0"\n  }\n]')" "superskills@"
  [ "$output" = "2.24.0" ]
  run _doctor_plugin_version '[]' "superskills@"
  [ -z "$output" ]
}

@test "check_plugin: accepts pre-fetched JSON so doctor_report calls the CLI only once" {
  run doctor_check_plugin "$ROOT" "definitely-not-claude-xyz" '[{"id":"superskills@superskills","version":"2.24.0"}]'
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"matches VERSION"* ]]
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
  [[ "$output" == *"| Plugin | unverified |"* ]]
}

@test "check_plugin: a sibling plugin alone does not count as the superskills plugin" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  fake_plugin_list "$FAKE" "superskills-marketing@superskills=2.24.0"
  run doctor_check_plugin "$ROOT" "$FAKE"
  [[ "$(evidence_of "$output")" == *"not installed as a Claude Code plugin"* ]]
}

@test "check_knowledge: expands ~ against the inspected home, not the real HOME" {
  CONF="$HOME_DIR/.superskills/knowledge.conf"; mkdir -p "$(dirname "$CONF")" "$HOME_DIR/.superskills/knowledge/kb1/.git"
  printf 'kb1|~/.superskills/knowledge/kb1|desc|https://example.invalid/kb1.git\n' > "$CONF"
  run doctor_check_knowledge "$CONF" "$HOME_DIR"
  [ "$(status_of "$output")" = "ready" ]
  [[ "$(evidence_of "$output")" == *"all cloned"* ]]
}

# ── hook ──

@test "check_hook: warning when the root is not a git checkout" {
  run doctor_check_hook "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"not a git checkout"* ]]
}

@test "check_hook: warning when the checkout has no post-merge hook" {
  git -C "$ROOT" init -q
  run doctor_check_hook "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"not installed"* ]]
}

@test "check_hook: ready when our post-merge hook is installed" {
  git -C "$ROOT" init -q
  cp "$ROOT/scripts/git-hooks/post-merge" "$ROOT/.git/hooks/post-merge"
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
  before=$(find "$ROOT" "$HOME_DIR" | sort | md5)
  run doctor_report "$ROOT" "$HOME_DIR" "definitely-not-claude-xyz"
  [ "$status" -eq 0 ]
  after=$(find "$ROOT" "$HOME_DIR" | sort | md5)
  [ "$before" = "$after" ]
  [[ "$output" == *"| Check"* ]]
  [[ "$output" == *"Verdict:"* ]]
  # gstack is absent in this fixture, so the verdict must not be "ready"
  [[ "$output" != *"Verdict: ready"* ]]
}

# ── scripts/doctor.sh wrapper (arg parsing; the report itself is tested above) ──

@test "doctor.sh: --root and --home point the report at another checkout and home" {
  FAKE="$BATS_TEST_TMPDIR/claude"; printf '#!/bin/sh\necho "[]"\n' > "$FAKE"; chmod +x "$FAKE"
  run bash "$REPO_ROOT/scripts/doctor.sh" --root "$ROOT" --home "$HOME_DIR" --bin "$FAKE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"superskills v2.24.0 at $ROOT"* ]]
  [[ "$output" == *"| Plugin | ready | not installed"* ]]
  [[ "$output" == *"linked into $SKILLS"* ]]
}

@test "doctor.sh: --root=/--home= forms are accepted" {
  run bash "$REPO_ROOT/scripts/doctor.sh" "--root=$ROOT" "--home=$HOME_DIR" --bin=definitely-not-claude-xyz
  [ "$status" -eq 0 ]
  [[ "$output" == *"| Plugin | unverified |"* ]]
  [[ "$output" == *"at $ROOT"* ]]
}

@test "doctor.sh: an unknown option exits 2 with a message" {
  run bash "$REPO_ROOT/scripts/doctor.sh" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option: --bogus"* ]]
}

@test "doctor.sh: --help prints usage and exits 0" {
  run bash "$REPO_ROOT/scripts/doctor.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--root"* ]]
}

