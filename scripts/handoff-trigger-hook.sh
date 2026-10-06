#!/usr/bin/env bash
# handoff-trigger-hook.sh — Claude Code hook (UserPromptSubmit). Emits ONE
# additionalContext nudge to run /handoff when account usage (the statusline's
# rate-limit cache) crosses HANDOFF_USAGE_THRESHOLD (default 90). Re-arms once
# per new rate-limit window (the marker stores the firing window's resets_at).
# Never fails the prompt path: any parse problem -> silent exit 0.
#
# Cache shape (scripts/statusline.sh, second jq record):
#   {"rate_limits":{"five_hour":{"used_percentage":N,"resets_at":ISO},...}}
# Highest pressure across live windows wins; jq does the float-safe compare
# and returns the firing window's resets_at for the marker.
set -u
input="$(cat 2>/dev/null || true)"
[ -n "$input" ] || exit 0
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
[ -n "$session_id" ] || exit 0

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
CACHE="$CACHE_DIR/rate-limits.json"
MARKER="$CACHE_DIR/handoff-notified-$session_id"

verdict="$(jq -r --arg t "${HANDOFF_USAGE_THRESHOLD:-90}" '
  [.rate_limits[]?.used_percentage // 0] as $p
  | if ($p | max) >= ($t | tonumber)
    then "1 " + ([.rate_limits[]? | select(.used_percentage == ($p | max))
                  | (.resets_at // "" | tostring)][0] // "")
    else "0 " end' "$CACHE" 2>/dev/null || echo '0 ')"
fire="${verdict%% *}"
resets_at="${verdict#* }"
[ "$fire" = "1" ] || exit 0
[ -e "$MARKER" ] && [ "$(cat "$MARKER" 2>/dev/null)" = "$resets_at" ] && exit 0

jq -n --arg ctx "Session usage is at or above ${HANDOFF_USAGE_THRESHOLD:-90}%. Run the /handoff skill NOW, before doing anything else: it writes handoff.md (in-progress state, exact next steps, and this session's reference) so a fresh session can resume cheaply. Session reference for the note: transcript_path=${transcript}; session_id=${session_id}. After /handoff completes, continue the user's task." \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
printf '%s' "$resets_at" > "$MARKER" 2>/dev/null || true
exit 0
