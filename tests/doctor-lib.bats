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

@test "check_repo: blocked when the root is not a superskills checkout" {
  run doctor_check_repo "$BATS_TEST_TMPDIR/nope"
  [ "$(status_of "$output")" = "blocked" ]
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

# ── commands ──

@test "check_command: ready when present, warning when missing (optional)" {
  run doctor_check_command "bash" "needed for everything"
  [ "$(status_of "$output")" = "ready" ]
  run doctor_check_command "definitely-not-a-command-xyz" "needed for /fuzz"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"/fuzz"* ]]
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

@test "check_plugin: warning when the installed plugin version lags VERSION" {
  FAKE="$BATS_TEST_TMPDIR/claude"
  printf '#!/bin/sh\necho "[{\\"id\\":\\"superskills@superskills\\",\\"version\\":\\"2.20.0\\",\\"enabled\\":true}]"\n' > "$FAKE"; chmod +x "$FAKE"
  run doctor_check_plugin "$ROOT" "$FAKE"
  [ "$(status_of "$output")" = "warning" ]
  [[ "$(evidence_of "$output")" == *"2.20.0"* ]]
}

# ── hook ──

@test "check_hook: warning when the post-merge hook is not installed" {
  run doctor_check_hook "$ROOT"
  [ "$(status_of "$output")" = "warning" ]
}

# ── verdict ──

@test "verdict: blocked if any required row is blocked, even with everything else ready" {
  rows=$(printf 'Repo\tready\tok\nLinks\tblocked\tbad\nbun\tready\tok\n')
  run doctor_verdict "$rows"
  [ "$output" = "blocked" ]
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
