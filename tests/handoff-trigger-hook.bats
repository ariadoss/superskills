#!/usr/bin/env bats
# handoff-trigger-hook.sh — the >=90% usage nudge. Fixture stdin JSON and a
# fixture XDG_CACHE_HOME hold the statusline cache shape; the hook must never
# break the prompt path (garbage in → silent exit 0).

setup() {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  HOOK="$REPO_ROOT/scripts/handoff-trigger-hook.sh"
  CACHE_HOME="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$CACHE_HOME/claude-statusline"
  CACHE="$CACHE_HOME/claude-statusline/rate-limits.json"
  STDIN_JSON='{"hook_event_name":"UserPromptSubmit","session_id":"abc","transcript_path":"/t/p.jsonl","cwd":"/r"}'
}

@test "fires above threshold with correctly-nested additionalContext" {
  printf '%s' '{"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":"2026-10-06T20:00:00Z"},"seven_day":{"used_percentage":41,"resets_at":"2026-10-09T12:00:00Z"}}}' > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | test("/handoff") and test("p.jsonl") and test("abc")' >/dev/null
  [ -f "$CACHE_HOME/claude-statusline/handoff-notified-abc" ]
  [ "$(cat "$CACHE_HOME/claude-statusline/handoff-notified-abc")" = "2026-10-06T20:00:00Z" ]
}

@test "silent below threshold" {
  printf '%s' '{"rate_limits":{"five_hour":{"used_percentage":62,"resets_at":"2026-10-06T20:00:00Z"}}}' > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "marker for the same window suppresses; a new window re-fires" {
  printf '%s' '{"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":"2026-10-06T20:00:00Z"}}}' > "$CACHE"
  printf '%s' '2026-10-06T20:00:00Z' > "$CACHE_HOME/claude-statusline/handoff-notified-abc"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  printf '%s' '{"rate_limits":{"five_hour":{"used_percentage":91,"resets_at":"2026-10-07T02:00:00Z"}}}' > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$(cat "$CACHE_HOME/claude-statusline/handoff-notified-abc")" = "2026-10-07T02:00:00Z" ]
}

@test "fractional percentages compare float-safely" {
  printf '%s' '{"rate_limits":{"five_hour":{"used_percentage":92.7,"resets_at":"2026-10-06T21:00:00Z"}}}' > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "garbage or missing cache degrades to silent exit 0" {
  printf 'not json at all' > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  rm -f "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "HANDOFF_USAGE_THRESHOLD is honored" {
  printf '%s' '{"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":"2026-10-06T20:00:00Z"}}}' > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' HANDOFF_USAGE_THRESHOLD=95 bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "empty stdin is silent exit 0" {
  run bash -c "XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK' < /dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
