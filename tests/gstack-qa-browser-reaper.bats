#!/usr/bin/env bats
# Unit tests for scripts/gstack-qa-browser-reaper.sh — idle gstack QA browser
# reaper. Hermetic: a temp GSTACK_HOME + a fixture process list fed through the
# GSTACK_QA_REAP_PS_FILE test seam (no live `ps`, no processes killed).
#
# macOS-only: the reaper uses BSD `stat -f` / `ps` and is wired to launchd.

setup() {
  [ "$(uname)" = "Darwin" ] || skip "reaper is macOS-only"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/gstack-qa-browser-reaper.sh"

  export GSTACK_HOME="$BATS_TEST_TMPDIR/gstack"
  mkdir -p "$GSTACK_HOME"

  # An idle QA profile (dir mtime 40 min ago) and a fresh one (now).
  IDLE_PROF="$GSTACK_HOME/chromium-profile-testqa"
  FRESH_PROF="$GSTACK_HOME/chromium-profile-freshqa"
  mkdir -p "$IDLE_PROF" "$FRESH_PROF"
  touch -t "$(date -v-40M +%Y%m%d%H%M)" "$IDLE_PROF"

  CFT="/Applications/x/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"
  EXT="--load-extension=/x/gstack/extension"

  # Fixture process list: idle QA main, fresh QA main, a helper for the idle
  # profile (--type=), a crashpad handler, real Chrome, and Firefox.
  export GSTACK_QA_REAP_PS_FILE="$BATS_TEST_TMPDIR/ps.txt"
  cat > "$GSTACK_QA_REAP_PS_FILE" <<EOF
1001 $CFT $EXT --user-data-dir=/any/.gstack/chromium-profile-testqa --remote-debugging-pipe about:blank
1002 $CFT $EXT --user-data-dir=/any/.gstack/chromium-profile-freshqa --remote-debugging-pipe about:blank
1003 /Applications/x/Google Chrome for Testing Helper.app/Contents/MacOS/Google Chrome for Testing Helper --type=renderer --user-data-dir=/any/.gstack/chromium-profile-testqa
1004 /x/Frameworks/chrome_crashpad_handler --database=/any/Chrome for Testing/Crashpad
1005 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
1006 /Applications/Firefox.app/Contents/MacOS/firefox
EOF
}

@test "dry-run reaps an idle QA browser" {
  run env GSTACK_QA_REAP_IDLE_MIN=30 bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"WOULD REAP  profile=testqa pid=1001"* ]]
}

@test "dry-run spares a freshly-active QA browser" {
  run env GSTACK_QA_REAP_IDLE_MIN=30 bash "$SCRIPT" --dry-run
  [[ "$output" != *"profile=freshqa"* ]]
}

@test "scoping: ignores helpers, crashpad, real Chrome, and Firefox" {
  run env GSTACK_QA_REAP_IDLE_MIN=30 bash "$SCRIPT" --dry-run
  # Exactly one candidate (the idle QA main) — nothing else matches.
  reap_lines="$(printf '%s\n' "$output" | grep -c 'WOULD REAP' || true)"
  [ "$reap_lines" -eq 1 ]
}

@test "idle threshold is honored (nothing reaped below it)" {
  run env GSTACK_QA_REAP_IDLE_MIN=60 bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"WOULD REAP"* ]]
}

@test "skips a profile with no on-disk dir (safety)" {
  rm -rf "$IDLE_PROF"
  run env GSTACK_QA_REAP_IDLE_MIN=30 bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"profile=testqa"* ]]
}

@test "real run is best-effort: exit 0 and logs even when the pid is gone" {
  # pid 1001 doesn't exist as a killable target here; kill failures are swallowed.
  run env GSTACK_QA_REAP_IDLE_MIN=30 bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "reaping profile=testqa pid=1001" "$GSTACK_HOME/qa-reaper.log"
}
