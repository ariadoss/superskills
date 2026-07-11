#!/usr/bin/env bash
# install-qa-browser-reaper.sh — opt-in installer for the idle QA browser reaper.
#
# Installs a launchd LaunchAgent that runs scripts/gstack-qa-browser-reaper.sh
# every N seconds, so orphaned gstack QA browsers (see that script's header) get
# cleaned up regardless of how a skill or Claude session ended. Also prints the
# Claude Code SessionEnd hook snippet for immediate cleanup on session close.
#
# This is NOT run by ./setup — it installs a background agent that force-kills
# idle browser processes, which must be a deliberate, opt-in choice. macOS only.
#
# Usage:
#   scripts/install-qa-browser-reaper.sh [--idle-min N] [--interval SECS]
#   scripts/install-qa-browser-reaper.sh --uninstall
#
# Defaults: idle-min 30, interval 900 (15 min).

set -euo pipefail

LABEL="com.superskills.gstack-qa-reaper"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REAPER="$REPO_ROOT/scripts/gstack-qa-browser-reaper.sh"
UID_NUM="$(id -u)"
LOG="$HOME/.gstack/qa-reaper.launchd.log"

IDLE_MIN=30
INTERVAL=900
ACTION=install

need_int() { case "${2:-}" in ''|*[!0-9]*) echo "$1 needs a positive integer value" >&2; exit 2 ;; esac; }
while [ $# -gt 0 ]; do
  case "$1" in
    --idle-min)  need_int "$1" "${2:-}"; IDLE_MIN="$2"; shift 2 ;;
    --interval)  need_int "$1" "${2:-}"; INTERVAL="$2"; shift 2 ;;
    --uninstall) ACTION=uninstall; shift ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ "$(uname)" = "Darwin" ] || { echo "This installer is macOS-only (launchd)." >&2; exit 1; }

bootout() { launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || launchctl unload "$PLIST" 2>/dev/null || true; }

if [ "$ACTION" = "uninstall" ]; then
  bootout
  rm -f "$PLIST"
  echo "Uninstalled $LABEL (removed $PLIST)."
  echo "If you added the SessionEnd hook to ~/.claude/settings.json, remove it manually."
  exit 0
fi

[ -f "$REAPER" ] || { echo "reaper not found at $REAPER" >&2; exit 1; }
chmod +x "$REAPER"
mkdir -p "$(dirname "$PLIST")" "$HOME/.gstack"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$REAPER</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>GSTACK_QA_REAP_IDLE_MIN</key><string>$IDLE_MIN</string>
  </dict>
  <key>StartInterval</key><integer>$INTERVAL</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF

# Reload cleanly (idempotent): bootout any prior instance, then bootstrap.
bootout
if launchctl bootstrap "gui/$UID_NUM" "$PLIST" 2>/dev/null || launchctl load "$PLIST" 2>/dev/null; then
  launchctl kickstart -k "gui/$UID_NUM/$LABEL" 2>/dev/null || true
  echo "Installed $LABEL"
  echo "  reaper:    $REAPER"
  echo "  idle-min:  $IDLE_MIN    interval: ${INTERVAL}s"
  echo "  log:       $LOG"
else
  echo "Failed to load LaunchAgent. Plist written to $PLIST; load it manually with:" >&2
  echo "  launchctl bootstrap gui/$UID_NUM \"$PLIST\"" >&2
  exit 1
fi

cat <<EOF

Optional — also reap on Claude Code session close. Add this to the "hooks"
object in ~/.claude/settings.json:

  "SessionEnd": [
    { "hooks": [ { "type": "command",
        "command": "/bin/bash $REAPER >/dev/null 2>&1 &" } ] }
  ]

Uninstall anytime:  scripts/install-qa-browser-reaper.sh --uninstall
EOF
