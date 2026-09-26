#!/usr/bin/env bash
# install-statusline.sh [--settings <path>] [--force]
#
# Points Claude Code's statusLine at scripts/statusline.sh in the checkout this
# script lives in, by editing settings.json. Safe to re-run:
#   - every other setting is kept; the original is backed up first
#   - an identical statusLine is a no-op (no rewrite, no backup)
#   - a different statusLine is left alone unless --force
#   - invalid JSON is refused, never overwritten
# Default settings file: ${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json.
# Tested in tests/install-statusline.bats.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --settings) SETTINGS="$2"; shift 2 ;;
    --force)    FORCE=1; shift ;;
    -h|--help)  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install-statusline: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "install-statusline: jq is required (the statusline itself runs on jq)." >&2
  echo "  macOS: brew install jq    Debian/Ubuntu: sudo apt install jq" >&2
  exit 1
fi

script="$SCRIPT_DIR/statusline.sh"
[ -f "$script" ] || { echo "install-statusline: $script not found" >&2; exit 1; }
chmod +x "$script"

# Claude Code runs the command through a shell, so a path with spaces or other
# shell characters must be quoted. Plain paths stay unquoted (easier to read).
case "$script" in
  *[!A-Za-z0-9_./-]*) command="'$(printf '%s' "$script" | sed "s/'/'\\\\''/g")'" ;;
  *) command="$script" ;;
esac

mkdir -p "$(dirname "$SETTINGS")"
if [ -f "$SETTINGS" ]; then
  if ! jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1; then
    echo "install-statusline: $SETTINGS is not a valid JSON object; not touching it." >&2
    exit 1
  fi
  current="$(jq -r '.statusLine.command // empty' "$SETTINGS")"
  if [ "$current" = "$command" ]; then
    echo "statusline already installed in $SETTINGS"
    exit 0
  fi
  if [ -n "$current" ] && [ "$FORCE" -ne 1 ]; then
    echo "install-statusline: $SETTINGS already has a statusLine:" >&2
    echo "  $current" >&2
    echo "Re-run with --force to replace it (the file is backed up first)." >&2
    exit 1
  fi
  backup="$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
  cp -p "$SETTINGS" "$backup"
  tmp="$SETTINGS.tmp.$$"
  cp -p "$SETTINGS" "$tmp"   # keeps the original's permissions on the new file
  jq --arg c "$command" '.statusLine = {type: "command", command: $c}' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  echo "statusline installed in $SETTINGS (previous version: $backup)"
else
  jq -n --arg c "$command" '{statusLine: {type: "command", command: $c}}' > "$SETTINGS"
  echo "statusline installed in new $SETTINGS"
fi
echo "It takes effect on Claude Code's next statusline refresh."
