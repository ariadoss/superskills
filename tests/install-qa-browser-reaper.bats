#!/usr/bin/env bats
# Tests for scripts/install-qa-browser-reaper.sh — the opt-in launchd installer.
# Hermetic: HOME is a temp dir and `launchctl` is a fake on PATH that records
# its arguments (FAKE_LAUNCHCTL_FAIL makes bootstrap/load fail), so nothing is
# ever loaded into the real launchd.

setup() {
  [ "$(uname)" = "Darwin" ] || skip "installer is macOS-only"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/install-qa-browser-reaper.sh"
  export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME"
  FAKEBIN="$BATS_TEST_TMPDIR/bin"; mkdir -p "$FAKEBIN"
  export LAUNCHCTL_LOG="$BATS_TEST_TMPDIR/launchctl.log"; : > "$LAUNCHCTL_LOG"
  cat > "$FAKEBIN/launchctl" <<'SH'
#!/bin/sh
echo "$*" >> "$LAUNCHCTL_LOG"
case "$1" in
  bootstrap|load) [ -n "$FAKE_LAUNCHCTL_FAIL" ] && exit 5 ;;
  bootout|unload) exit 3 ;;   # nothing loaded yet: real launchctl fails here too
esac
exit 0
SH
  chmod +x "$FAKEBIN/launchctl"
  export PATH="$FAKEBIN:$PATH"
  PLIST="$HOME/Library/LaunchAgents/com.superskills.gstack-qa-reaper.plist"
}

@test "install writes the plist with the requested idle-min and interval, then bootstraps and kickstarts" {
  run bash "$SCRIPT" --idle-min 45 --interval 600
  [ "$status" -eq 0 ]
  [ -f "$PLIST" ]
  grep -q '<key>GSTACK_QA_REAP_IDLE_MIN</key><string>45</string>' "$PLIST"
  grep -q '<key>StartInterval</key><integer>600</integer>' "$PLIST"
  grep -q "<string>$REPO_ROOT/scripts/gstack-qa-browser-reaper.sh</string>" "$PLIST"
  plutil -lint "$PLIST" >/dev/null
  grep -q '^bootstrap gui/' "$LAUNCHCTL_LOG"
  grep -q '^kickstart -k gui/.*/com.superskills.gstack-qa-reaper$' "$LAUNCHCTL_LOG"
  [[ "$output" == *"Installed com.superskills.gstack-qa-reaper"* ]] || false
}

@test "defaults are idle-min 30 and interval 900" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q '<string>30</string>' "$PLIST"
  grep -q '<integer>900</integer>' "$PLIST"
}

@test "re-installing is idempotent: it boots out the previous agent before bootstrapping" {
  bash "$SCRIPT" >/dev/null
  : > "$LAUNCHCTL_LOG"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(grep -n '^bootout' "$LAUNCHCTL_LOG" | head -1 | cut -d: -f1)" -lt "$(grep -n '^bootstrap' "$LAUNCHCTL_LOG" | cut -d: -f1)" ]
}

@test "when launchd refuses the agent it exits 1, keeps the plist and prints the manual command" {
  FAKE_LAUNCHCTL_FAIL=1 run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [ -f "$PLIST" ]
  [[ "$output" == *"launchctl bootstrap gui/"* ]] || false
}

@test "--uninstall removes the plist and exits 0, also when nothing was installed" {
  run bash "$SCRIPT" --uninstall
  [ "$status" -eq 0 ]
  bash "$SCRIPT" >/dev/null
  run bash "$SCRIPT" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$PLIST" ]
}

@test "non-integer values and unknown flags exit 2 without writing anything" {
  run bash "$SCRIPT" --idle-min soon
  [ "$status" -eq 2 ]
  [[ "$output" == *"--idle-min needs a positive integer"* ]] || false
  run bash "$SCRIPT" --interval
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
  [ ! -e "$PLIST" ]
  [ ! -s "$LAUNCHCTL_LOG" ]
}
