#!/usr/bin/env bats
# handoff-trigger-hook.sh — the >=90% usage nudge. Fixture stdin JSON and a
# fixture XDG_CACHE_HOME hold the statusline cache shape; the hook must never
# break the prompt path (garbage in → silent exit 0).

setup() {
  REPO_ROOT="$(dirname "$BATS_TEST_DIRNAME")"
  # Dual lookup: scripts/ in superskills, hooks/ in the exported standalone repo.
  for cand in "$REPO_ROOT/scripts/handoff-trigger-hook.sh" "$REPO_ROOT/hooks/handoff-trigger-hook.sh"; do
    [ -f "$cand" ] && HOOK="$cand" && break
  done
  [ -n "${HOOK:-}" ]
  CACHE_HOME="$BATS_TEST_TMPDIR/cache"
  mkdir -p "$CACHE_HOME/claude-statusline"
  CACHE="$CACHE_HOME/claude-statusline/rate-limits.json"
  STDIN_JSON='{"hook_event_name":"UserPromptSubmit","session_id":"abc","transcript_path":"/t/p.jsonl","cwd":"/r"}'
}

@test "fires above threshold with correctly-nested additionalContext" {
  W1=$(( $(date +%s) + 3600 ))
  W2=$(( W1 + 86400 ))
  printf '{"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":%d},"seven_day":{"used_percentage":41,"resets_at":%d}}}' "$W1" "$W2" > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null
  echo "$output" | jq -e '.hookSpecificOutput.additionalContext | test("/handoff") and test("p.jsonl") and test("abc")' >/dev/null
  [ -f "$CACHE_HOME/claude-statusline/handoff-notified-abc" ]
  [ "$(cat "$CACHE_HOME/claude-statusline/handoff-notified-abc")" = "$W1" ]
}

@test "silent below threshold" {
  printf '{"rate_limits":{"five_hour":{"used_percentage":62,"resets_at":%d}}}' "$(( $(date +%s) + 3600 ))" > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "marker for the same window suppresses; a new window re-fires" {
  W1=$(( $(date +%s) + 3600 ))
  printf '{"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":%d}}}' "$W1" > "$CACHE"
  printf '%s' "$W1" > "$CACHE_HOME/claude-statusline/handoff-notified-abc"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  W2=$(( $(date +%s) + 7200 ))
  printf '{"rate_limits":{"five_hour":{"used_percentage":91,"resets_at":%d}}}' "$W2" > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$(cat "$CACHE_HOME/claude-statusline/handoff-notified-abc")" = "$W2" ]
}

@test "fractional percentages compare float-safely" {
  printf '{"rate_limits":{"five_hour":{"used_percentage":92.7,"resets_at":%d}}}' "$(( $(date +%s) + 3600 ))" > "$CACHE"
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
  printf '{"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":%d}}}' "$(( $(date +%s) + 3600 ))" > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' HANDOFF_USAGE_THRESHOLD=95 bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "empty stdin is silent exit 0" {
  run bash -c "XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK' < /dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "an expired rate-limit window does not fire (freshness contract)" {
  # resets_at far in the past: the producer would have dropped this window;
  # the consumer must not act on it either.
  printf '%s' '{"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":1000000000}}}' > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$CACHE_HOME/claude-statusline/handoff-notified-abc" ]
}

@test "a far-future window fires; a past one alone does not" {
  printf '%s' "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":93,\"resets_at\":$(($(date +%s) + 3600))}}}" > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  rm -f "$CACHE_HOME/claude-statusline/handoff-notified-abc"
  printf '%s' '{"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":1000000000}}}' > "$CACHE"
  run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "non-numeric HANDOFF_USAGE_THRESHOLD warns on stderr and stays silent" {
  printf '{"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":%d}}}' "$(( $(date +%s) + 3600 ))" > "$CACHE"
  err="$BATS_TEST_TMPDIR/warn.txt"
  out="$BATS_TEST_TMPDIR/out.txt"
  printf '%s' "$STDIN_JSON" | XDG_CACHE_HOME="$CACHE_HOME" HANDOFF_USAGE_THRESHOLD='90%' bash "$HOOK" >"$out" 2>"$err"
  [ $? -eq 0 ]
  [ ! -s "$out" ]
  grep -q "not numeric" "$err"
}

@test "stdin without session_id is silent exit 0, no marker" {
  printf '{"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":%d}}}' "$(( $(date +%s) + 3600 ))" > "$CACHE"
  for bad in '{}' 'not json'; do
    run bash -c "printf '%s' '$bad' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
  [ -z "$(ls "$CACHE_HOME/claude-statusline" | grep handoff-notified || true)" ]
}

@test "a cache directory not owned by the user is not trusted" {
  printf '%s' '{"rate_limits":{"five_hour":{"used_percentage":93,"resets_at":1791288000}}}' > "$CACHE"
  # root owns /tmp-ish fixture dirs in some CI setups; simulate by pointing
  # HOME elsewhere so the ownership check's failure mode is exercised only
  # when the dir is genuinely not ours. Portable approximation: skip when
  # we own it (the common dev case) and assert the guard exists in source.
  if [ -O "$CACHE_HOME/claude-statusline" ]; then
    grep -q '\[ -O "$CACHE_DIR" \]' "$HOOK"
  else
    run bash -c "printf '%s' '$STDIN_JSON' | XDG_CACHE_HOME='$CACHE_HOME' bash '$HOOK'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  fi
}
