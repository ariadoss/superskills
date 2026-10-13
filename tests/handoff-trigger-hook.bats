#!/usr/bin/env bats
# The automatic nudge fires on this session's context window (90%), the account's
# 5-hour window (90%) and the weekly window (95%), once each, never on a fresh session.
setup() {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  for cand in "$REPO_ROOT/scripts/handoff-trigger-hook.sh" "$REPO_ROOT/hooks/handoff-trigger-hook.sh"; do
    [ -f "$cand" ] && HOOK="$cand" && break
  done
  CACHE_HOME="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$CACHE_HOME/claude-statusline"
  CACHE="$CACHE_HOME/claude-statusline/context-abc.json"
  STDIN_JSON='{"hook_event_name":"UserPromptSubmit","session_id":"abc","transcript_path":"/t/p.jsonl"}'
}

invoke() {
  printf '%s' "$STDIN_JSON" | XDG_CACHE_HOME="$CACHE_HOME" bash "$HOOK"
}

rate_limits() { # five_hour_pct seven_day_pct [resets_in_seconds]
  local r=$(( $(date +%s) + ${3:-3600} ))
  printf '{"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%d},"seven_day":{"used_percentage":%s,"resets_at":%d}}}' \
    "$1" "$r" "$2" "$r" > "$CACHE_HOME/claude-statusline/rate-limits.json"
}

@test "5-hour window at 90% triggers; at 89% does not" {
  rate_limits 89 10
  run invoke
  [ -z "$output" ]
  rate_limits 90 10
  run invoke
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | test("5-hour") and test("handoff-abc.md")' >/dev/null
}

@test "weekly window triggers at 95% but not at 94%" {
  rate_limits 10 94
  run invoke
  [ -z "$output" ]
  rate_limits 10 95
  run invoke
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | test("weekly")' >/dev/null
}

@test "an account window nudges once per window, and re-arms when it rolls over" {
  rate_limits 95 10 3600
  run invoke
  [ -n "$output" ]
  run invoke
  [ -z "$output" ]
  rate_limits 95 10 7200
  run invoke
  [ -n "$output" ]
}

@test "an expired window (resets_at in the past) never triggers" {
  rate_limits 99 99 -60
  run invoke
  [ -z "$output" ]
}

@test "account usage never nudges a session that has not replied yet" {
  rate_limits 99 10
  printf '%s\n' '{"type":"mode"}' '{"type":"user","message":"hi"}' > "$BATS_TEST_TMPDIR/fresh.jsonl"
  STDIN_JSON="{\"session_id\":\"abc\",\"transcript_path\":\"$BATS_TEST_TMPDIR/fresh.jsonl\"}"
  run invoke
  [ -z "$output" ]
  printf '%s\n' '{"type":"assistant","message":"done"}' >> "$BATS_TEST_TMPDIR/fresh.jsonl"
  run invoke
  [ -n "$output" ]
}

@test "context and account triggers are independent: one handoff does not silence the other" {
  printf '{"used_percentage":91}' > "$CACHE"
  run invoke
  [ -n "$output" ]
  rate_limits 95 10
  run invoke
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | test("5-hour")' >/dev/null
}

@test "a non-numeric account threshold warns and disables only that trigger" {
  rate_limits 99 10
  printf '{"used_percentage":95}' > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' HANDOFF_FIVE_HOUR_THRESHOLD=abc bash '$HOOK' 2>&1"
  echo "$output" | grep -q "HANDOFF_FIVE_HOUR_THRESHOLD not numeric"
  echo "$output" | grep -q "context window"
  ! echo "$output" | grep -q "5-hour usage window" || false
}

@test "context at 90% triggers once per session" {
  printf '{"used_percentage":90}' > "$CACHE"
  run invoke
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | test("context window") and test("/handoff") and test("p.jsonl")' >/dev/null
  run invoke
  [ -z "$output" ]
}

@test "statusline reading at threshold feeds the hook" {
  [ -f "$REPO_ROOT/scripts/statusline.sh" ] || skip "standalone export uses the installed superskills statusline"
  printf '%s' '{"session_id":"abc","context_window":{"used_percentage":89}}' |
    XDG_CACHE_HOME="$CACHE_HOME" bash "$REPO_ROOT/scripts/statusline.sh" >/dev/null
  run invoke
  [ -z "$output" ]
  printf '%s' '{"session_id":"abc","context_window":{"used_percentage":90}}' |
    XDG_CACHE_HOME="$CACHE_HOME" bash "$REPO_ROOT/scripts/statusline.sh" >/dev/null
  run invoke
  [ -n "$output" ]
}

@test "old account-window marker does not suppress a context threshold nudge" {
  printf '{"used_percentage":90}' > "$CACHE"
  printf '%s' '1791288000' > "$CACHE_HOME/claude-statusline/handoff-notified-abc"
  run invoke
  [ -n "$output" ]
}

@test "threshold can be set to 95%" {
  printf '{"used_percentage":93}' > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' HANDOFF_USAGE_THRESHOLD=95 bash '$HOOK'"
  [ -z "$output" ]
  printf '{"used_percentage":95}' > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' HANDOFF_USAGE_THRESHOLD=95 bash '$HOOK'"
  [ -n "$output" ]
}

@test "another session's context cannot trigger this session" {
  printf '{"used_percentage":99}' > "$CACHE_HOME/claude-statusline/context-other.json"
  run invoke
  [ -z "$output" ]
}

@test "missing, corrupt, or nonnumeric context stays silent" {
  for bad in '' 'garbage' '{"used_percentage":"99"}' '{"used_percentage":null}'; do
    if [ -n "$bad" ]; then printf '%s' "$bad" > "$CACHE"; else rm -f "$CACHE"; fi
    run invoke
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "invalid session id cannot escape the cache directory" {
  STDIN_JSON='{"session_id":"../../elsewhere","transcript_path":"/t/p.jsonl"}'
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "invalid threshold stays silent" {
  printf '{"used_percentage":99}' > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' HANDOFF_USAGE_THRESHOLD='90%' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not numeric"* ]] || false
}

@test "malformed stdin stays silent" {
  printf '{"used_percentage":99}' > "$CACHE"
  STDIN_JSON='not json'
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "nudge names this session's own handoff file, never bare handoff.md" {
  printf '{"used_percentage":95}' > "$CACHE"
  run invoke
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("handoff-abc.md") and (test("handoff\\.md") | not)' >/dev/null
}

@test "statusline account windows feed the hook end to end (5-hour 90, weekly 95)" {
  [ -f "$REPO_ROOT/scripts/statusline.sh" ] || skip "standalone export uses the installed superskills statusline"
  resets=$(( $(date +%s) + 7200 ))
  render() {
    printf '{"session_id":"abc","context_window":{"used_percentage":10},"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%d},"seven_day":{"used_percentage":%s,"resets_at":%d}}}' \
      "$1" "$resets" "$2" "$resets" | XDG_CACHE_HOME="$CACHE_HOME" bash "$REPO_ROOT/scripts/statusline.sh" >/dev/null
  }
  render 89 94
  run invoke
  [ -z "$output" ]
  render 90 94
  run invoke
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | test("5-hour") and (test("weekly") | not)' >/dev/null
  render 90 95
  run invoke
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | test("weekly")' >/dev/null
}
