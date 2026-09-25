#!/usr/bin/env bash
# install-qa-full-ledger-hook.sh — prints the Claude Code settings snippet for
# the /qa-full ledger check (scripts/qa-full-ledger-hook.sh).
#
# Plugin installs already get the hook from hooks/hooks.json. For ./setup
# installs, hooks are a deliberate opt-in, so this script does not edit
# ~/.claude/settings.json; it prints what to add. Claude Code picks up the
# change without a restart.
#
# Usage: scripts/install-qa-full-ledger-hook.sh

set -euo pipefail
HOOK="$(cd "$(dirname "$0")" && pwd)/qa-full-ledger-hook.sh"
[ -f "$HOOK" ] || { echo "hook not found at $HOOK" >&2; exit 1; }
chmod +x "$HOOK"
command -v jq >/dev/null 2>&1 || echo "Note: the hook needs jq and does nothing without it (brew install jq)." >&2

cat <<EOF
Add these entries to the "hooks" object in ~/.claude/settings.json:

  "Stop": [
    { "hooks": [ { "type": "command", "command": "\"$HOOK\"" } ] }
  ],
  "SubagentStop": [
    { "hooks": [ { "type": "command", "command": "\"$HOOK\"" } ] }
  ]

It exits at once unless the session ran /qa-full. When it did, it blocks the
stop if a ledger row says a check ran but that sub-skill was never invoked.
Remove the two entries to uninstall.
EOF
