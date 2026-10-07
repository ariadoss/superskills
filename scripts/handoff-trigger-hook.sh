#!/usr/bin/env bash
# handoff-trigger-hook.sh — Claude Code hook (UserPromptSubmit). Emits ONE
# additionalContext nudge to run /handoff when account usage (the statusline's
# rate-limit cache) crosses HANDOFF_USAGE_THRESHOLD (default 90). Re-arms once
# per new rate-limit window (the marker stores the firing window's resets_at).
# Never fails the prompt path: any parse problem -> silent exit 0.
#
# Cache shape (scripts/statusline.sh, second jq record):
#   {"rate_limits":{"five_hour":{"used_percentage":N,"resets_at":<epoch seconds, number>},...}}
# Producer contract mirrored here (statusline.sh live()): a window counts only
# while resets_at > now, and the cache is trusted only from a user-owned dir
# as a regular file. Highest pressure across LIVE windows wins; jq does the
# float-safe compare and returns the firing window's resets_at for the marker.
set -u
input="$(cat 2>/dev/null || true)"
[ -n "$input" ] || exit 0
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
[ -n "$session_id" ] || exit 0

# The one user-controlled input: a typo must not silently disable the nudge.
threshold="${HANDOFF_USAGE_THRESHOLD:-90}"
case "$threshold" in ''|*[!0-9.]*)
  echo "handoff-trigger-hook: HANDOFF_USAGE_THRESHOLD not numeric: '$threshold' (nudge disabled)" >&2
  exit 0
esac

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
CACHE="$CACHE_DIR/rate-limits.json"
MARKER="$CACHE_DIR/handoff-notified-$session_id"
# Same trust rules as the producer (statusline.sh): a cache dir someone else
# owns could hold spoofed numbers or a FIFO; a non-regular file is not read.
[ -d "$CACHE_DIR" ] && [ -O "$CACHE_DIR" ] || exit 0
[ -f "$CACHE" ] || exit 0

verdict="$(jq -r --arg t "$threshold" '
  [.rate_limits[]? | select((.resets_at // 0) > now) | .used_percentage // 0] as $p
  | if ($p | max) >= ($t | tonumber)
    then "1 " + ([.rate_limits[]? | select((.resets_at // 0) > now)
                  | select(.used_percentage == ($p | max))
                  | (.resets_at | tostring)][0] // "")
    else "0 " end' "$CACHE" 2>/dev/null || echo '0 ')"
fire="${verdict%% *}"
resets_at="${verdict#* }"
[ "$fire" = "1" ] || exit 0
[ -e "$MARKER" ] && [ "$(cat "$MARKER" 2>/dev/null)" = "$resets_at" ] && exit 0

jq -n --arg ctx "Session usage is at or above ${threshold}%. Run the /handoff skill before continuing this task: it writes handoff.md (in-progress state, exact next steps, and this session's reference) so a fresh session can resume cheaply. Session reference for the note: transcript_path=${transcript}; session_id=${session_id}. After /handoff completes, continue the user's task." \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
if ! printf '%s' "$resets_at" > "$MARKER" 2>/dev/null; then
  # Unwritable cache dir would re-nudge every prompt of the window; say so once.
  echo "handoff-trigger-hook: cannot write marker $MARKER; this nudge may repeat each prompt this window" >&2
fi
exit 0
