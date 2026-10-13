#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook: nudge /handoff once per trigger when
#   - this session's context window reaches HANDOFF_USAGE_THRESHOLD (90%), or
#   - the account's 5-hour window reaches HANDOFF_FIVE_HOUR_THRESHOLD (90%), or
#   - the account's weekly window reaches HANDOFF_WEEKLY_THRESHOLD (95%).
# The 5-hour window resets within hours, so firing early wastes a note, but a
# heavy turn can burn several percent of it. The weekly bucket is larger (a
# turn moves it a point or two) and every new session nudges while it stays
# above the line, so it fires later. Never nudges a session with fewer than
# MIN_ASSISTANT_TURNS replies (nothing worth handing off yet). Parse failures
# stay silent.
set -u
input="$(cat 2>/dev/null || true)"
[ -n "$input" ] || exit 0
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
case "$session_id" in ''|*[!a-zA-Z0-9_-]*) exit 0 ;; esac

# A typo must not silently disable a trigger: warn, then disable only that one.
DISABLED=1000000
MIN_ASSISTANT_TURNS=3
threshold_of() {
  local var="$1" default="$2" val
  val="${!var:-$default}"
  if ! [[ "$val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "handoff-trigger-hook: $var not numeric: '$val' (that trigger disabled)" >&2
    printf '%s' "$DISABLED"; return
  fi
  printf '%s' "$val"
}
ctx_threshold="$(threshold_of HANDOFF_USAGE_THRESHOLD 90)"
five_threshold="$(threshold_of HANDOFF_FIVE_HOUR_THRESHOLD 90)"
week_threshold="$(threshold_of HANDOFF_WEEKLY_THRESHOLD 95)"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
[ -d "$CACHE_DIR" ] && [ -O "$CACHE_DIR" ] || exit 0

# Each firing trigger is "<marker-suffix>|<marker-value>|<reason>". Context
# fires once per session; an account window re-arms when it rolls over (its
# marker stores the window's resets_at).
triggers=()

ctx_cache="$CACHE_DIR/context-$session_id.json"
ctx_marker="$CACHE_DIR/handoff-notified-$session_id"
if [ -f "$ctx_cache" ]; then
  # "1 <pct>" at/over the threshold, "0" below it, nothing when unreadable.
  reading="$(jq -r --arg t "$ctx_threshold" '
    if (.used_percentage | type) != "number" then empty
    elif .used_percentage >= ($t | tonumber) then "1 \(.used_percentage)"
    else "0" end' "$ctx_cache" 2>/dev/null)"
  armed=1
  [ -f "$ctx_marker" ] && [ "$(cat "$ctx_marker" 2>/dev/null)" = notified ] && armed=0
  if [ "$reading" = "0" ] && [ "$armed" = 0 ]; then
    rm -f "$ctx_marker"   # context fell back (compact): re-arm for the next climb
  elif [ "${reading%% *}" = "1" ] && [ "$armed" = 1 ]; then
    triggers+=("|notified|this session's context window is at ${reading#* }% (threshold ${ctx_threshold}%)")
  fi
fi

# Same trust rules as the statusline producer: user-owned dir (checked above),
# regular file, and a window counts only while its resets_at is in the future.
rl_cache="$CACHE_DIR/rate-limits.json"
if [ -f "$rl_cache" ]; then
  while IFS=$'\t' read -r key pct resets; do
    [ -n "$key" ] || continue
    marker="$CACHE_DIR/handoff-notified-$session_id-$key"
    # The marker holds the window's reset epoch. The producer can wobble it by a second
    # or two between refreshes; only a real rollover (hours later) re-arms.
    if [ -f "$marker" ] && [ -r "$marker" ]; then
      seen="$(cat "$marker" 2>/dev/null)"
      if [[ "$seen" =~ ^[0-9]+$ ]]; then
        diff=$(( resets > seen ? resets - seen : seen - resets ))
        [ "$diff" -lt 600 ] && continue
      fi
    fi
    case "$key" in
      five_hour) label="the 5-hour usage window is at ${pct}% (threshold ${five_threshold}%)" ;;
      *)         label="the weekly usage window is at ${pct}% (threshold ${week_threshold}%)" ;;
    esac
    triggers+=("-$key|$resets|$label")
  done < <(jq -r --argjson f "$five_threshold" --argjson w "$week_threshold" '
    .rate_limits as $r
    | [["five_hour", $f], ["seven_day", $w]][] as [$k, $t]
    | ($r[$k]? // empty)
    | select(type == "object"
             and (.resets_at | type) == "number" and .resets_at > now
             and (.used_percentage | type) == "number" and .used_percentage >= $t)
    | "\($k)\t\(.used_percentage)\t\(.resets_at | floor)"' "$rl_cache" 2>/dev/null)
fi

[ "${#triggers[@]}" -gt 0 ] || exit 0

# An account window that was already high when a brand-new session started must not
# make its first prompts write a note: little has been done yet. grep stops at the
# MIN_ASSISTANT_TURNS-th reply. An unreadable transcript is not evidence of a fresh session.
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  turns="$(grep -m "$MIN_ASSISTANT_TURNS" -cE '"type": ?"assistant"' "$transcript" 2>/dev/null || true)"
  [ "${turns:-0}" -ge "$MIN_ASSISTANT_TURNS" ] || exit 0
fi

reasons=""
for t in "${triggers[@]}"; do
  suffix="${t%%|*}"; rest="${t#*|}"; value="${rest%%|*}"; label="${rest#*|}"
  reasons="${reasons:+$reasons; }$label"
  # temp file (noclobber) then rename: a planted symlink at the marker path is replaced,
  # never written through.
  marker="$CACHE_DIR/handoff-notified-$session_id$suffix"
  tmp="$marker.$$.tmp"
  if ! { ( set -C; printf '%s' "$value" > "$tmp" ) 2>/dev/null && mv -f "$tmp" "$marker" 2>/dev/null; }; then
    rm -f "$tmp" 2>/dev/null
    echo "handoff-trigger-hook: cannot write marker for $session_id$suffix; this nudge may repeat" >&2
  fi
done

jq -n --arg ctx "Handoff trigger: ${reasons}. Run the /handoff skill before continuing this task: it writes handoff-${session_id}.md at the repo root (in-progress state, exact next steps, and this session's reference) so a fresh session can resume cheaply. Session reference for the note: transcript_path=${transcript}; session_id=${session_id}; export HANDOFF_SESSION_ID=${session_id} when running the skill's session-ref script. After /handoff completes, continue the user's task." \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
exit 0
