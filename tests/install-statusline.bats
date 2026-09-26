#!/usr/bin/env bats
# Tests for scripts/install-statusline.sh: points Claude Code's statusLine at this
# checkout's scripts/statusline.sh by editing settings.json, safely.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  INSTALL="$REPO_ROOT/scripts/install-statusline.sh"
  SL="$REPO_ROOT/scripts/statusline.sh"
  SETTINGS="$BATS_TEST_TMPDIR/claude/settings.json"
  mkdir -p "$(dirname "$SETTINGS")"
}

cmd_of() { jq -r '.statusLine.command' "$1"; }

@test "creates settings.json when missing, pointing at this checkout's script" {
  run bash "$INSTALL" --settings "$SETTINGS"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(jq -r '.statusLine.type' "$SETTINGS")" = "command" ] || false
  [ "$(cmd_of "$SETTINGS")" = "$SL" ] || { echo "got $(cmd_of "$SETTINGS")"; return 1; }
}

@test "keeps every other setting and backs up the original" {
  printf '{"model":"opus","permissions":{"allow":["Bash(ls)"]}}\n' > "$SETTINGS"
  run bash "$INSTALL" --settings "$SETTINGS"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(jq -r '.model' "$SETTINGS")" = "opus" ] || false
  [ "$(jq -r '.permissions.allow[0]' "$SETTINGS")" = "Bash(ls)" ] || false
  [ "$(cmd_of "$SETTINGS")" = "$SL" ] || false
  bak="$(ls "$SETTINGS".bak-* 2>/dev/null | head -1)"
  [ -n "$bak" ] || { echo "no backup"; return 1; }
  [ "$(jq -r '.model' "$bak")" = "opus" ] || false
}

@test "already installed is a no-op: no rewrite, no backup" {
  printf '{"statusLine":{"type":"command","command":"%s"}}\n' "$SL" > "$SETTINGS"
  run bash "$INSTALL" --settings "$SETTINGS"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"already"* ]] || false
  [ -z "$(ls "$SETTINGS".bak-* 2>/dev/null)" ] || { echo "made a backup for a no-op"; return 1; }
}

@test "will not replace someone else's statusline without --force" {
  printf '{"statusLine":{"type":"command","command":"~/my-line.sh"}}\n' > "$SETTINGS"
  run bash "$INSTALL" --settings "$SETTINGS"
  [ "$status" -eq 1 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" == *"~/my-line.sh"* && "$output" == *"--force"* ]] || { echo "$output"; return 1; }
  [ "$(cmd_of "$SETTINGS")" = "~/my-line.sh" ] || false
  run bash "$INSTALL" --settings "$SETTINGS" --force
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(cmd_of "$SETTINGS")" = "$SL" ] || false
}

@test "refuses a settings.json that is not valid JSON, leaving it untouched" {
  printf '{ "model": "opus", \n' > "$SETTINGS"
  run bash "$INSTALL" --settings "$SETTINGS"
  [ "$status" -eq 1 ] || { echo "status $status"; return 1; }
  [ "$(cat "$SETTINGS")" = '{ "model": "opus", ' ] || false
}

@test "fails clearly when jq is missing" {
  bin="$BATS_TEST_TMPDIR/bin"; mkdir -p "$bin"
  for t in bash cat mkdir mv cp date dirname basename cd chmod printf; do
    p="$(command -v "$t" 2>/dev/null)" && [ -x "$p" ] && ln -sf "$p" "$bin/$t"
  done
  run env PATH="$bin" "$bin/bash" "$INSTALL" --settings "$SETTINGS"
  [ "$status" -eq 1 ] || { echo "status $status: $output"; return 1; }
  [[ "$output" == *"jq"* ]] || false
}

@test "a checkout path with spaces is quoted so the shell runs it" {
  d="$BATS_TEST_TMPDIR/my repo/scripts"; mkdir -p "$d"
  cp "$INSTALL" "$SL" "$d/"
  run bash "$d/install-statusline.sh" --settings "$SETTINGS"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  cmd="$(cmd_of "$SETTINGS")"
  run bash -c "$cmd" <<< '{"model":{"display_name":"Opus"}}'
  [ "$status" -eq 0 ] || { echo "cmd [$cmd] failed: $output"; return 1; }
  [[ "$output" == *"Opus"* ]] || false
}

@test "honors CLAUDE_CONFIG_DIR when no --settings is given" {
  run env CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/cfg" bash "$INSTALL"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(cmd_of "$BATS_TEST_TMPDIR/cfg/settings.json")" = "$SL" ] || false
}

@test "./setup recognizes --statusline (and --help documents it)" {
  run "$REPO_ROOT/setup" --statusline --list-skills
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  run "$REPO_ROOT/setup" --help
  [[ "$output" == *"--statusline"* ]] || false
}
